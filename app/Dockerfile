# Stage 1: build the React strangler frontend (static output only, no SSR)
FROM node:22-alpine AS react-build

WORKDIR /build

COPY webapp-react/package*.json ./
RUN npm ci

COPY webapp-react/ ./
RUN npm run build

# Stage 2: existing Express runtime (unchanged behavior)
FROM node:16-alpine

WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy the application files
COPY server.js ./
COPY services/ ./services/
COPY public/ ./public/

# Static React build served by the strangler router
COPY --from=react-build /build/dist ./webapp-react/dist

# Ensure the public directory exists
RUN mkdir -p /app/public

# Expose the port
EXPOSE 3000

# Start the application
CMD ["node", "server.js"]
