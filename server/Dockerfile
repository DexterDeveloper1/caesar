# Build stage: compile TypeScript with dev dependencies available.
FROM node:24-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig*.json ./
COPY src ./src
RUN npm run build

# Runtime stage: production dependencies and compiled output only.
FROM node:24-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist

# Scores are written here; mount a volume to persist them across restarts.
ENV DATA_FILE=/data/scores.json
VOLUME ["/data"]

EXPOSE 3000
CMD ["node", "dist/main.js"]
