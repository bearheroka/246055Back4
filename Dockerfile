FROM nginx:latest
EXPOSE 80
WORKDIR /app
USER root

COPY nginx.conf /etc/nginx/nginx.conf
COPY config.json ./
COPY entrypoint.sh ./

RUN apt-get update && apt-get install -y wget unzip qrencode iproute2 systemctl && \
    wget -O cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i cloudflared.deb && \
	cloudflared service install eyJhIjoiMThkMGY2OTk4MDkxOGNlMDgxOGM5NjZjYmY4NzcwYTgiLCJ0IjoiMWY4NGQ5YWYtZWYyMy00YWFhLTgzMmQtMTIzOTk1ZGEyZjM3IiwicyI6Ik9EVmtNR1k0WkRrdFpXUmpZUzAwWWpZMUxXRmlNakV0WldGbU5XUTNOVGd6TkRNNSJ9 && \
    rm -f cloudflared.deb && \
    wget -O temp.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip && \
    unzip temp.zip xray && \
    rm -f temp.zip && \
    chmod -v 755 xray entrypoint.sh

ENTRYPOINT [ "./entrypoint.sh" ]