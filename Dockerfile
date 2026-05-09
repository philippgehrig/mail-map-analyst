FROM node:20-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src/ ./src/
RUN npm run build

# Build mail-mcp: it has src + package.json but no tsconfig when installed via git
# Create a minimal tsconfig and compile with the parent's tsc
RUN echo '{"compilerOptions":{"target":"ES2022","module":"ESNext","moduleResolution":"bundler","esModuleInterop":true,"strict":false,"outDir":"dist","rootDir":"src","declaration":true,"skipLibCheck":true,"noImplicitAny":false},"include":["src/**/*"]}' > node_modules/mail-mcp/tsconfig.json \
    && cd node_modules/mail-mcp \
    && /app/node_modules/.bin/tsc --project tsconfig.json

FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    zstd \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://ollama.com/install.sh | sh

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules/mail-mcp/dist ./node_modules/mail-mcp/dist
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENV OLLAMA_URL=http://localhost:11434
ENV OLLAMA_MODEL=gemma2:2b

ENTRYPOINT ["/app/entrypoint.sh"]
