FROM node:20-slim AS frontend-builder

WORKDIR /app

# Copy package files
COPY package.json ./

# Install Node dependencies
RUN npm install

# Copy frontend source
COPY index.html ./
COPY vite.config.js ./
COPY tailwind.config.js ./
COPY postcss.config.js ./
COPY src/ ./src/

# Build React app
RUN npm run build

# Ruby backend stage
FROM ruby:3.2-slim

WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile ./
RUN bundle install

# Copy backend files
COPY app.rb .
COPY config.ru .
COPY dap_sync.sh .

# Copy built frontend from builder stage
COPY --from=frontend-builder /app/public ./public

# Create data directory for sync selection file
RUN mkdir -p /data

EXPOSE 3000

CMD ["bundle", "exec", "ruby", "app.rb"]
