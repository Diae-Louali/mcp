FROM python:3.11-slim

# Install system dependencies  
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*    

# Install uv
RUN pip install --no-cache-dir uv

# Set working directory
WORKDIR /app

# Install runtime dependencies directly into system environment
RUN uv pip install --system \
  "asyncmy>=0.2.10" \
  "fastmcp[cli]==2.2.8" \
  "google-genai>=1.15.0" \
  "google-generativeai>=0.8.5" \
  "openai>=1.78.1" \
  "python-dotenv>=1.1.0" \
  "sentence-transformers>=4.1.0" \
  "tokenizers==0.21.2"

COPY . /app
EXPOSE 9101

CMD ["python", "src/server.py", "--host", "0.0.0.0", "--transport", "sse", "--port", "9101"]