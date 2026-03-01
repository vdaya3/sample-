import os
import json
import requests
import gradio as gr
from autogen import AssistantAgent, UserProxyAgent, GroupChat, GroupChatManager

# =====================================================
# LLM CONFIG (LM Studio - DeepSeek)
# =====================================================

# llm_config = {
#     "config_list": [
#         {
#             "model": "deepseek-r1-distill-llama-8b",
#             "base_url": "http://127.0.0.1:1234/v1",
#             "api_key": "lm-studio",
#         }
#     ],
#     "temperature": 0,
# }

llm_config = {
    "config_list": [
        {
            "model": "gemini-2.5-flash-lite",
            "api_key": os.getenv("GOOGLE_API_KEY", "AIzaSyCi5mCQKWY9XBPcg_zC8DeB9h5-snKL9AI"),
            "base_url": "https://generativelanguage.googleapis.com/v1beta/openai",
        }
    ],
    "temperature": 0,
    "max_tokens": 1200,
}

# =====================================================
# MCP SERVER BASE URL
# =====================================================

MCP_BASE_URL = "http://127.0.0.1:8000"

# =====================================================
# TOOL WRAPPERS (Bridge to FastMCP)
# =====================================================

def list_pull_request_files(pr_url: str):
    response = requests.post(
        f"{MCP_BASE_URL}/tools/list_pull_request_files",
        json={"pr_url": pr_url},
        timeout=60
    )
    return response.json()

def create_review_comment(pr_url: str, body: str, commit_id: str, path: str, line: int):
    response = requests.post(
        f"{MCP_BASE_URL}/tools/create_review_comment",
        json={
            "pr_url": pr_url,
            "body": body,
            "commit_id": commit_id,
            "path": path,
            "line": line
        },
        timeout=60
    )
    return response.json()

def create_pull_request_review(pr_url: str, body: str):
    response = requests.post(
        f"{MCP_BASE_URL}/tools/create_pull_request_review",
        json={
            "pr_url": pr_url,
            "body": body
        },
        timeout=60
    )
    return response.json()

# =====================================================
# AGENTS
# =====================================================

# PR Fetch Agent
pr_fetch_agent = AssistantAgent(
    name="PRFetchAgent",
    llm_config=llm_config,
    system_message="""
You must call list_pull_request_files tool using the PR URL.
Return changed Java files and their patches.
"""
)

pr_fetch_agent.register_function(
    function_map={
        "list_pull_request_files": list_pull_request_files
    }
)

# Java Review Agent
java_review_agent = AssistantAgent(
    name="JavaReviewAgent",
    llm_config=llm_config,
    system_message="""
You are a senior Java architect.

Review only changed Java patches.

Detect:
- Bugs
- NullPointerException risks
- Concurrency issues
- Transaction issues
- Security risks
- Performance problems
- Code smells

Return STRICT JSON ARRAY ONLY:

[
 {
   "file": "...",
   "line": number,
   "severity": "CRITICAL | HIGH | MEDIUM | LOW | INFO",
   "type": "BUG | SECURITY | PERFORMANCE | SMELL | DESIGN",
   "message": "...",
   "suggestion": "...",
   "code_snippet": "..."
 }
]
"""
)

# Inline Comment Agent
inline_agent = AssistantAgent(
    name="InlineCommentAgent",
    llm_config=llm_config,
    system_message="""
For each issue in the JSON array:
Call create_review_comment tool.

Include severity, message, and suggestion in formatted body.
"""
)

inline_agent.register_function(
    function_map={
        "create_review_comment": create_review_comment
    }
)

# Summary Agent
summary_agent = AssistantAgent(
    name="SummaryAgent",
    llm_config=llm_config,
    system_message="""
Aggregate all issues.
Count by severity.
Provide merge recommendation.
Call create_pull_request_review tool.
Return summary.
"""
)

summary_agent.register_function(
    function_map={
        "create_pull_request_review": create_pull_request_review
    }
)

# User Proxy
# user_proxy = UserProxyAgent(
#     name="User",
#     human_input_mode="NEVER"
# )

user_proxy = UserProxyAgent(
    name="User",
    human_input_mode="NEVER",
    code_execution_config=False
)

# =====================================================
# GROUP CHAT
# =====================================================

groupchat = GroupChat(
    agents=[
        user_proxy,
        pr_fetch_agent,
        java_review_agent,
        inline_agent,
        summary_agent
    ],
    messages=[],
    max_round=30,
)

manager = GroupChatManager(
    groupchat=groupchat,
    llm_config=llm_config
)

# =====================================================
# EXECUTION FUNCTION
# =====================================================

def run_review(pr_url):
    task = f"""
Perform full Java PR review for:
{pr_url}

Steps:
1. Fetch changed files.
2. Review Java code.
3. Post inline comments.
4. Post final summary review.
"""

    result = user_proxy.initiate_chat(
        manager,
        message=task
    )

    final_summary = (
        result.summary
        if hasattr(result, "summary") and result.summary
        else "Review Completed."
    )

    return final_summary, "Execution finished successfully."

# =====================================================
# GRADIO UI
# =====================================================

with gr.Blocks() as demo:
    gr.Markdown("## Enterprise Java PR Reviewer (FastMCP + AutoGen)")

    with gr.Row():
        summary_box = gr.Textbox(label="Final Summary", lines=20)
        logs_box = gr.Textbox(label="Logs", lines=20)

    pr_input = gr.Textbox(label="Pull Request URL")
    run_btn = gr.Button("Run Review")

    run_btn.click(
        fn=run_review,
        inputs=pr_input,
        outputs=[summary_box, logs_box]
    )

if __name__ == "__main__":
    demo.launch(server_port=7860)
