from fastapi import FastAPI
from pydantic import BaseModel
from fastapi.responses import JSONResponse
from openai import OpenAI
import json
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Get token securely
HF_TOKEN = os.getenv("HF_TOKEN")

# Stop app if token not found
if not HF_TOKEN:
    raise ValueError("HF_TOKEN not set in environment variables")

app = FastAPI()

# Create OpenAI client using secure token
client = OpenAI(
    base_url="https://router.huggingface.co/v1",
    api_key=HF_TOKEN,
)
class ExplainRequest(BaseModel):
    topic: str
    content: str
    subject: str | None = "science"


@app.post("/explain")
def explain_topic(data: ExplainRequest):

    subject = (data.subject or "science").strip().lower()

    # ================= MATHS SYSTEM PROMPT =================

    if subject in ["maths", "math", "mathematics"]:

        system_prompt = """
You are an expert Indian Mathematics teacher.

STRICT INSTRUCTIONS:
- Understand topic carefully.
- Adapt explanation based on chapter.
- Show complete step-by-step solution.
- Perform internal verification of calculations.
- DO NOT show verification steps in output.
- DO NOT include words like "Verify".
- Final answer must be correct.
- Use × symbol for multiplication.
- Return ONLY valid JSON.
- No markdown.
- No explanation outside JSON.

Return strictly in this format:

{
 "concept_explanation": "Explain concept step-by-step in small clear points",
 "general_steps": ["Step 1","Step 2","Step 3"],
 "textbook_example": {
    "question": "Example question",
    "solution_steps": ["Step 1 calculation","Step 2 calculation"],
    "final_answer": "Final correct answer only"
 },
 "new_example": {
    "question": "New question",
    "solution_steps": ["Step 1 calculation","Step 2 calculation"],
    "final_answer": "Final correct answer only"
 },
 "summary": "Short summary"
}
"""

    # ================= SCIENCE SYSTEM PROMPT =================

    else:

        system_prompt = """
You are an expert Indian Science teacher.

STRICT INSTRUCTIONS:
- Understand topic carefully.
- Explain concept clearly and correctly.
- Do not give false or made-up information.
- Use simple student-friendly language.
- Return ONLY valid JSON.
- No markdown.
- No explanation outside JSON.

Return strictly in this format:

{
 "concept_explanation": "Clear explanation",
 "key_points": ["Point 1","Point 2"],
 "textbook_example": "Short example from topic",
 "real_life_application": "How it applies in real life",
 "summary": "Short summary"
}
"""

    try:
        completion = client.chat.completions.create(
            model="meta-llama/Meta-Llama-3-70B-Instruct:featherless-ai",
            messages=[
                {"role": "system", "content": system_prompt},
                {
                    "role": "user",
                     "content": f"""
Subject: {subject}
Topic: {data.topic}

Explain properly according to this topic only.
Do not assume any fixed method.

Content:
{data.content}
"""
                 }
            ],
            temperature=0.2,
            max_tokens=900,
            response_format={"type": "json_object"}
        )

        parsed = json.loads(completion.choices[0].message.content)

        return JSONResponse(content={"explanation": parsed})

    except Exception as e:
        print("AI Error:", str(e))

        # Safe fallback response
        if subject in ["maths", "math", "mathematics"]:
            fallback = {
                "concept_explanation": "AI response error. Please retry.",
                "general_steps": [],
                "textbook_example": {
                    "question": "",
                    "solution_steps": [],
                    "final_answer": ""
                },
                "new_example": {
                    "question": "",
                    "solution_steps": [],
                    "final_answer": ""
                },
                "summary": "Please retry."
            }
        else:
            fallback = {
                "concept_explanation": "AI response error. Please retry.",
                "key_points": [],
                "textbook_example": "",
                "real_life_application": "",
                "summary": "Please retry."
            }

        return JSONResponse(content={"explanation": fallback})
