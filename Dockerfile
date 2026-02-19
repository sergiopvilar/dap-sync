FROM node:20-slim AS frontend-builder

WORKDIR /dap-sync

# Copy package files
COPY package.json ./

# Install Node dependencies
RUN npm install

# Copy frontend source
COPY index.html ./
COPY vite.config.js ./
COPY tailwind.config.js ./
COPY postcss.config.js ./
COPY app/ ./app/
COPY src/ ./src/

# Build React app
RUN npm run build

# Ruby backend stage
FROM ruby:3.2-slim

WORKDIR /dap-sync

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile ./
RUN bundle install

# Copy backend files
COPY app.rb .
COPY config.ru .
COPY config.yaml .
COPY src/ ./src/

# Copy built frontend from builder stage
COPY --from=frontend-builder /dap-sync/public ./public

# Create data directory for sync selection file
RUN mkdir -p /data

EXPOSE 3000

# Run from /dap-sync so Bundler finds the Gemfile (avoids "Could not locate Gemfile" when WORKDIR is overridden at runtime)
CMD ["sh", "-c", "pwd && ls && cd /dap-sync && exec bundle exec ruby app.rb"]
