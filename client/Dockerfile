# Build step #1: build the front end
FROM node:lts-alpine as build-step
WORKDIR /app
COPY package.json  ./
COPY ./src ./src
COPY ./index.html ./
COPY ./index.js ./
COPY ./elm.json ./
RUN npm install
RUN npm run build

# Build step #2: build a Caddy container
FROM caddy:alpine
EXPOSE 80
COPY --from=build-step /app/dist /app/client