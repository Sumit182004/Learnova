from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from fastapi.responses import JSONResponse
from openai import OpenAI
import json
import os
from dotenv import load_dotenv

load_dotenv()

HF_TOKEN = os.getenv("HF_TOKEN")
if not HF_TOKEN:
    raise ValueError("HF_TOKEN not set in environment variables")

app = FastAPI()

# FIX: CORS middleware — required for Flutter web and cross-origin requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

client = OpenAI(
    base_url="https://router.huggingface.co/v1",
    api_key=HF_TOKEN,
)

# ── Request model ──────────────────────────────────────────────────────────────
class ExplainRequest(BaseModel):
    topic: str
    content: str
    subject: str | None = "science"
    language: str | None = "english"   # FIX: language param added for Hindi support later


# ── Helper: normalize subject name ────────────────────────────────────────────
def normalize_subject(subject: str) -> str:
    """
    Accepts any variation admin might use:
    maths, math, mathematics, science, science-i, science-ii,
    science1, science2, physics, chemistry, biology
    Returns: "maths" or "science"
    """
    s = subject.strip().lower().replace(" ", "").replace("-", "")
    if s in ["maths", "math", "mathematics"]:
        return "maths"
    return "science"   # everything else — science-i, science-ii, physics, chemistry, biology


# ── /explain endpoint ──────────────────────────────────────────────────────────
@app.post("/explain")
def explain_topic(data: ExplainRequest):

    subject_type = normalize_subject(data.subject or "science")
    # FIX: language instruction in prompt
    lang = (data.language or "english").strip().lower()
    lang_instruction = (
        "Respond in Hindi (Devanagari script)."
        if lang == "hindi"
        else "Respond in English."
    )

    # ── Maths prompt ───────────────────────────────────────────────────────
    if subject_type == "maths":
        system_prompt = f"""
You are an expert Indian Mathematics teacher for Class 10 and Class 12 students.

{lang_instruction}

STRICT INSTRUCTIONS:
- Understand the topic carefully before explaining.
- Show complete step-by-step solutions.
- Perform internal verification of all calculations.
- DO NOT show verification steps in output.
- DO NOT include words like "Verify" or "Check".
- Final answer must always be mathematically correct.
- Use × symbol for multiplication.
- Return ONLY valid JSON — no markdown, no explanation outside JSON.

Return strictly this JSON format:
{{
  "concept_explanation": "Clear explanation of the concept in simple points",
  "general_steps": ["Step 1", "Step 2", "Step 3"],
  "textbook_example": {{
    "question": "Example question from the topic",
    "solution_steps": ["Step 1", "Step 2", "Step 3"],
    "final_answer": "The final correct answer"
  }},
  "new_example": {{
    "question": "A different example question on the same concept",
    "solution_steps": ["Step 1", "Step 2", "Step 3"],
    "final_answer": "The final correct answer"
  }},
  "summary": "Short 2-3 line summary of the concept",
  "practice_questions": ["Question 1", "Question 2", "Question 3"]
}}
"""

    # ── Science / Physics / Chemistry / Biology prompt ─────────────────────
    else:
        system_prompt = f"""
You are an expert Indian Science teacher for Class 10 and Class 12 students.

{lang_instruction}

STRICT INSTRUCTIONS:
- Explain the concept clearly and accurately.
- Do not give false or made-up information.
- Use simple student-friendly language.
- Include real-life examples where possible.
- Return ONLY valid JSON — no markdown, no explanation outside JSON.

Return strictly this JSON format:
{{
  "concept_explanation": "Clear explanation of the concept",
  "key_points": ["Point 1", "Point 2", "Point 3"],
  "textbook_example": "A short example or application from the topic",
  "real_life_application": "How this concept applies in real daily life",
  "summary": "Short 2-3 line summary",
  "practice_questions": ["Question 1", "Question 2", "Question 3"]
}}
"""

    # ── Call HuggingFace model ─────────────────────────────────────────────
    try:
        completion = client.chat.completions.create(
            model="meta-llama/Meta-Llama-3-70B-Instruct:featherless-ai",
            messages=[
                {"role": "system", "content": system_prompt},
                {
                    "role": "user",
                    "content": f"""
Subject: {data.subject}
Topic: {data.topic}
Language: {lang}

Content from textbook:
{data.content}

Explain this topic properly according to the content above.
Do not assume fixed methods — base your explanation on the content provided.
"""
                }
            ],
            temperature=0.2,
            max_tokens=1200,   # FIX: increased — was cutting off practice_questions
            response_format={"type": "json_object"}
        )

        raw = completion.choices[0].message.content
        parsed = json.loads(raw)

        # FIX: ensure practice_questions always exists in response
        if "practice_questions" not in parsed:
            parsed["practice_questions"] = []

        return JSONResponse(content={"explanation": parsed})

    except json.JSONDecodeError as e:
        print("JSON parse error:", str(e))
        return JSONResponse(
            status_code=500,
            content={"error": "AI returned invalid JSON", "detail": str(e)}
        )

    except Exception as e:
        print("AI Error:", str(e))

        # ── Safe fallback so app never crashes ────────────────────────────
        if subject_type == "maths":
            fallback = {
                "concept_explanation": "Could not load explanation. Please retry.",
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
                "summary": "Please retry.",
                "practice_questions": []
            }
        else:
            fallback = {
                "concept_explanation": "Could not load explanation. Please retry.",
                "key_points": [],
                "textbook_example": "",
                "real_life_application": "",
                "summary": "Please retry.",
                "practice_questions": []
            }

        return JSONResponse(content={"explanation": fallback})


# ── Health check — Render will ping this to keep server warm ──────────────────
@app.get("/")
def health_check():
    return {"status": "ok", "service": "Learnova AI Backend"}