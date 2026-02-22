import os
import sys
import shutil
from dotenv import load_dotenv

from autogen import AssistantAgent
from autogen.agentchat.contrib.retrieve_user_proxy_agent import RetrieveUserProxyAgent

# ================= LOAD ENV =================
load_dotenv()

DOCS_PATH = "./docs"
CHROMA_PATH = "./chroma"

# SSL for corporate proxy
os.environ["SSL_CERT_FILE"] = os.getenv("SSL_CERT_FILE")
os.environ["REQUESTS_CA_BUNDLE"] = os.getenv("SSL_CERT_FILE")

# ============== RE-INGEST OPTION =================
if "--reingest" in sys.argv:
    if os.path.exists(CHROMA_PATH):
        shutil.rmtree(CHROMA_PATH)
        print("Chroma DB deleted. Fresh ingestion will occur.")

# ============== LLM CONFIG =================
llm_config = {
    "model": os.getenv("GAIP_LLM_MODEL"),
    "base_url": os.getenv("GAIP_CHAT_BASE"),
    "api_key": os.getenv("GAIP_TOKEN"),
    "temperature": 0,
    "default_headers": {
        "Authorization": f"Bearer {os.getenv('GAIP_TOKEN')}"
    }
}

assistant = AssistantAgent(
    name="assistant",
    llm_config=llm_config,
    system_message=(
        "You MUST answer ONLY using the retrieved context. "
        "If answer is not found in context, respond exactly: "
        "'Not found in source documents.'"
    ),
)

# ============== RAG PROXY =================
ragproxy = RetrieveUserProxyAgent(
    name="ragproxy",
    human_input_mode="NEVER",
    code_execution_config=False,
    retrieve_config={
        "task": "qa",
        "docs_path": DOCS_PATH,
        "chunk_token_size": 800,
        "model": os.getenv("GAIP_LLM_MODEL"),
        "embedding_model": os.getenv("GAIP_EMBEDDING_MODEL"),
        "vector_db": "chroma",
        "persist_path": CHROMA_PATH,
        "collection_name": "rag_collection",
        "get_or_create": True,
        "recursive": True,
        "verbose": True,
    },
)

# ============== FORCE INITIALIZATION =================
print("\nInitializing vector store...")
ragproxy.retrieve_docs("initialization", n_results=1)
print("Vector store ready.\n")

# ============== CLI LOOP =================
print("=== Enterprise RAG CLI ===")
print("Type 'exit' to quit\n")

while True:
    query = input("You: ")

    if query.lower() in ["exit", "quit"]:
        print("Goodbye.")
        break

    ragproxy.initiate_chat(
        assistant,
        message=query,
        clear_history=False,
    )

    print()