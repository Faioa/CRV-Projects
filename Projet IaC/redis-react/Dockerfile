FROM node
COPY . .
RUN ["yarn"]
RUN ["yarn", "build"]
ENTRYPOINT ["yarn", "start"]

