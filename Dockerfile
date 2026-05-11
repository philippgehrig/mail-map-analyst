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

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules/mail-mcp/dist ./node_modules/mail-mcp/dist

ENV OLLAMA_URL=http://ollama:11434
ENV OLLAMA_MODEL=gemma2:2b

CMD ["node", "/app/dist/index.js"]
