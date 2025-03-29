FROM node:hydrogen-alpine3.21 AS builder
WORKDIR /app
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile
COPY . .
RUN yarn build

FROM nginx:1.27.4-alpine-slim
COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

RUN apk add --no-cache sed

COPY config-init.sh /docker-entrypoint.d/40-config-init.sh
RUN chmod +x /docker-entrypoint.d/40-config-init.sh
RUN echo 'window.env = {};' > /usr/share/nginx/html/config.js

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD curl -f http://localhost:8080/ || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
