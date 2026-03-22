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
    language: str | None = "english"
    block_types: list[str] | None = []


# ── Normalize subject ──────────────────────────────────────────────────────────
def normalize_subject(subject: str) -> str:
    s = subject.strip().lower().replace(" ", "").replace("-", "")
    if s in ["maths", "math", "mathematics"]:
        return "maths"
    return "science"


# ── Detect topic type from block types ────────────────────────────────────────
def detect_topic_type(block_types: list) -> str:
    types = set(block_types)

    # exercise topic — now gets AI explanation too
    if "exercise" in types and "theory" not in types and "proof" not in types:
        return "exercise"

    # summary topic — now gets AI explanation too
    if "summary" in types and len(types) == 1:
        return "summary"

    # proof-based topic
    if "proof" in types:
        return "proof"

    # formula-based topic
    if "formula" in types and "example" in types and "proof" not in types:
        return "formula"

    # theorem-based topic
    if "theorem" in types:
        return "theorem"

    # activity/experiment topic
    if "activity" in types:
        return "activity"

    # theory + example
    if "example" in types and "theory" in types:
        return "example_theory"

    # pure theory
    if "theory" in types:
        return "theory"

    return "general"


# ── Build system prompt ────────────────────────────────────────────────────────
def build_system_prompt(subject_type: str, topic_type: str, lang_instruction: str, has_images: bool) -> str:

    image_note = ""
    if has_images:
        image_note = """
IMPORTANT: This topic has diagrams shown to the student.
When you see [Diagram present in textbook: ...] in the content:
- Reference the diagram naturally in your explanation
- Say things like "as shown in the diagram", "refer to the figure above"
- Connect your explanation to what the diagram shows
"""

    base = f"""You are an expert Indian {'Mathematics' if subject_type == 'maths' else 'Science'} teacher for Class 10 and Class 12 students.

{lang_instruction}
{image_note}
STRICT RULES:
- Base your explanation ONLY on the content provided.
- Use simple, student-friendly language.
- Return ONLY valid JSON. No markdown. No text outside JSON.
- All calculations must be mathematically correct.
- Use × for multiplication in maths.
"""

    # ── MATHS prompts ──────────────────────────────────────────────────────────
    if subject_type == "maths":

        if topic_type == "exercise":
            return base + """
This is an EXERCISE topic. Your job is to:
1. Explain the approach and method to solve these types of questions
2. Show ONE fully solved example with clear steps
3. Do NOT solve all questions — student will solve them

Return this JSON:
{
  "concept_explanation": "How to approach and think about these exercise questions. What method or concept to use.",
  "general_steps": ["Step 1 of the approach", "Step 2", "Step 3"],
  "textbook_example": {
    "question": "Pick the first exercise question and solve it completely",
    "solution_steps": ["Step 1 with calculation", "Step 2", "Step 3"],
    "final_answer": "The correct final answer"
  },
  "new_example": {
    "question": "Create a similar but different question",
    "solution_steps": ["Step by step solution"],
    "final_answer": "Final answer"
  },
  "summary": "Key tip for solving all remaining questions in this exercise",
  "practice_questions": []
}"""

        elif topic_type == "summary":
            return base + """
This is a CHAPTER SUMMARY topic. Your job is to:
1. Give a teacher-style recap of everything covered in the chapter
2. Highlight the most important points a student must remember
3. Connect all concepts together

Return this JSON:
{
  "concept_explanation": "Teacher-style recap of the entire chapter — what was covered and why it matters",
  "general_steps": ["Most important point 1 to remember", "Most important point 2", "Most important point 3"],
  "textbook_example": {
    "question": "Most likely exam question from this chapter",
    "solution_steps": ["How to answer it step by step"],
    "final_answer": "The answer"
  },
  "new_example": {
    "question": "Another important exam question",
    "solution_steps": ["Step by step"],
    "final_answer": "The answer"
  },
  "summary": "One final line — what is the most important thing from this chapter",
  "practice_questions": ["Important revision question 1", "Important revision question 2", "Important revision question 3"]
}"""

        elif topic_type == "proof":
            return base + """
This topic is a MATHEMATICAL PROOF. Explain the proof clearly step by step.

Return this JSON:
{
  "concept_explanation": "What we are trying to prove and why it matters",
  "general_steps": ["Step 1 of proof logic", "Step 2", "Step 3"],
  "textbook_example": {
    "question": "State what is being proved",
    "solution_steps": ["Each proof step explained simply"],
    "final_answer": "Conclusion of the proof"
  },
  "new_example": {
    "question": "A similar proof question",
    "solution_steps": ["Step by step proof"],
    "final_answer": "Conclusion"
  },
  "summary": "What was proved and the key idea behind it",
  "practice_questions": ["Question 1", "Question 2", "Question 3"]
}"""

        elif topic_type == "formula":
            return base + """
This topic contains a FORMULA. Explain what it means and how to apply it.

Return this JSON:
{
  "concept_explanation": "What this formula means and when to use it",
  "general_steps": ["Step 1 to apply formula", "Step 2", "Step 3"],
  "textbook_example": {
    "question": "Example using the formula",
    "solution_steps": ["Each calculation step clearly shown"],
    "final_answer": "Correct final answer"
  },
  "new_example": {
    "question": "Different example using same formula",
    "solution_steps": ["Step by step calculation"],
    "final_answer": "Correct final answer"
  },
  "summary": "When and how to use this formula",
  "practice_questions": ["Question 1", "Question 2", "Question 3"]
}"""

        elif topic_type == "theorem":
            return base + """
This topic contains a THEOREM. Explain what it states and how to apply it.

Return this JSON:
{
  "concept_explanation": "What the theorem states in simple words",
  "general_steps": ["How to apply this theorem step by step"],
  "textbook_example": {
    "question": "Example applying the theorem",
    "solution_steps": ["Each application step"],
    "final_answer": "Final answer"
  },
  "new_example": {
    "question": "Another example using the theorem",
    "solution_steps": ["Step by step"],
    "final_answer": "Final answer"
  },
  "summary": "The theorem in one line and its importance",
  "practice_questions": ["Question 1", "Question 2", "Question 3"]
}"""

        else:
            return base + """
Explain this maths topic clearly with concept, steps and examples.

Return this JSON:
{
  "concept_explanation": "Clear explanation of the concept",
  "general_steps": ["Step 1", "Step 2", "Step 3"],
  "textbook_example": {
    "question": "Example question from the topic",
    "solution_steps": ["Step by step solution"],
    "final_answer": "Final answer"
  },
  "new_example": {
    "question": "New example question",
    "solution_steps": ["Step by step solution"],
    "final_answer": "Final answer"
  },
  "summary": "Short summary of the concept",
  "practice_questions": ["Question 1", "Question 2", "Question 3"]
}"""

    # ── SCIENCE prompts ────────────────────────────────────────────────────────
    else:

        if topic_type == "exercise":
            return base + """
This is an EXERCISE topic. Your job is to:
1. Explain how to approach and think about these questions
2. Show ONE fully solved example
3. Do NOT solve all questions — student will solve them

Return this JSON:
{
  "concept_explanation": "How to approach these exercise questions. What concepts to apply and how to think.",
  "key_points": ["Approach point 1", "Approach point 2", "Common mistake to avoid"],
  "textbook_example": "Pick the first exercise question and show how to answer it completely",
  "real_life_application": "Why understanding this topic is useful in real life",
  "summary": "Key tip for answering all remaining questions in this exercise",
  "practice_questions": []
}"""

        elif topic_type == "summary":
            return base + """
This is a CHAPTER SUMMARY topic. Give a teacher-style recap of the entire chapter.

Return this JSON:
{
  "concept_explanation": "Teacher-style recap of the entire chapter — all topics covered and their connections",
  "key_points": ["Most important point 1 to remember for exam", "Most important point 2", "Most important point 3"],
  "textbook_example": "Most likely exam question from this chapter with a clear answer",
  "real_life_application": "How the concepts in this chapter connect to real life",
  "summary": "One final line — the single most important takeaway from this chapter",
  "practice_questions": ["Important revision question 1", "Important revision question 2", "Important revision question 3"]
}"""

        elif topic_type == "activity":
            return base + """
This topic contains a SCIENCE ACTIVITY or experiment. Explain what happens and why.

Return this JSON:
{
  "concept_explanation": "What concept this activity demonstrates and what happens during it",
  "key_points": ["Observation 1", "Observation 2", "What it proves"],
  "textbook_example": "What happens in this activity step by step",
  "real_life_application": "Where we see this phenomenon in daily life",
  "summary": "What this activity taught us",
  "practice_questions": ["Question 1", "Question 2", "Question 3"]
}"""

        elif topic_type == "formula":
            return base + """
This topic contains a CHEMICAL EQUATION or FORMULA. Explain what it represents.

Return this JSON:
{
  "concept_explanation": "What this equation or formula represents and means",
  "key_points": ["Key point 1 about this reaction", "Key point 2", "Key point 3"],
  "textbook_example": "Example showing how to use or balance this equation",
  "real_life_application": "Where this reaction or formula is seen in real life",
  "summary": "What this formula or equation tells us",
  "practice_questions": ["Question 1", "Question 2", "Question 3"]
}"""

        else:
            return base + """
Explain this science topic clearly.

Return this JSON:
{
  "concept_explanation": "Clear explanation of the concept",
  "key_points": ["Key point 1", "Key point 2", "Key point 3"],
  "textbook_example": "A short example or application from this topic",
  "real_life_application": "How this concept applies in real daily life",
  "summary": "Short 2-3 line summary",
  "practice_questions": ["Question 1", "Question 2", "Question 3"]
}"""


# ── Fallback ───────────────────────────────────────────────────────────────────
def get_fallback(subject_type: str) -> dict:
    if subject_type == "maths":
        return {
            "concept_explanation": "Could not load explanation. Please retry.",
            "general_steps": [],
            "textbook_example": {"question": "", "solution_steps": [], "final_answer": ""},
            "new_example": {"question": "", "solution_steps": [], "final_answer": ""},
            "summary": "Please retry.",
            "practice_questions": []
        }
    return {
        "concept_explanation": "Could not load explanation. Please retry.",
        "key_points": [],
        "textbook_example": "",
        "real_life_application": "",
        "summary": "Please retry.",
        "practice_questions": []
    }


# ── /explain endpoint ──────────────────────────────────────────────────────────
@app.post("/explain")
def explain_topic(data: ExplainRequest):

    subject_type = normalize_subject(data.subject or "science")
    lang         = (data.language or "english").strip().lower()
    block_types  = data.block_types or []

    lang_instruction = (
        "Respond in Hindi (Devanagari script)."
        if lang == "hindi"
        else "Respond in English."
    )

    # detect topic type
    topic_type = detect_topic_type(block_types)
    has_images = "image" in block_types

    # build right prompt
    system_prompt = build_system_prompt(
        subject_type, topic_type, lang_instruction, has_images
    )

    try:
        completion = client.chat.completions.create(
            model="meta-llama/Meta-Llama-3-70B-Instruct:featherless-ai",
            messages=[
                {"role": "system", "content": system_prompt},
                {
                    "role": "user",
                    "content": f"""Subject: {data.subject}
Topic: {data.topic}
Topic Type: {topic_type}
Language: {lang}
Has Diagrams: {has_images}

Content from textbook:
{data.content}

Explain this topic based on the content above.
If diagrams are mentioned, reference them naturally in your explanation.
"""
                }
            ],
            temperature=0.2,
            max_tokens=1500,
            response_format={"type": "json_object"}
        )

        raw    = completion.choices[0].message.content
        parsed = json.loads(raw)

        if "practice_questions" not in parsed:
            parsed["practice_questions"] = []

        return JSONResponse(content={"explanation": parsed})

    except json.JSONDecodeError as e:
        print("JSON parse error:", str(e))
        return JSONResponse(content={"explanation": get_fallback(subject_type)})

    except Exception as e:
        print("AI Error:", str(e))
        return JSONResponse(content={"explanation": get_fallback(subject_type)})


# ── Health check ───────────────────────────────────────────────────────────────
@app.get("/")
def health_check():
    return {"status": "ok", "service": "Learnova AI Backend"}