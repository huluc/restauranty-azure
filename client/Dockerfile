# ---------- Stage 1: build the React app ----------
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
# "/." keeps API calls on the same origin (works behind any domain)
ARG REACT_APP_SERVER_URL=/.
ENV REACT_APP_SERVER_URL=$REACT_APP_SERVER_URL \
    GENERATE_SOURCEMAP=false
RUN npm run build

# ---------- Stage 2: serve static files with non-root nginx ----------
FROM nginxinc/nginx-unprivileged:1.30.6-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:8080/ > /dev/null || exit 1
