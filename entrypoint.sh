#!/usr/bin/env bash

# 定义 UUID 及 伪装路径,请自行修改.(注意:伪装路径以 / 符号开始,为避免不必要的麻烦,请不要使用特殊符号.)
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
VMESS_WSPATH=${VMESS_WSPATH:-'/vmess'}
VLESS_WSPATH=${VLESS_WSPATH:-'/vless'}
TROJAN_WSPATH=${TROJAN_WSPATH:-'/trojan'}
SS_WSPATH=${SS_WSPATH:-'/shadowsocks'}
# Argo 固定域名隧道的两个参数,这个可以填 Json 内容或 Token 内容，获取方式看 https://github.com/fscarmen2/X-for-Glitch，不需要的话可以留空，删除或在这三行最前面加 # 以注释
ARGO_AUTH=''
ARGO_DOMAIN=
sed -i "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g;s#TROJAN_WSPATH#${TROJAN_WSPATH}#g;s#SS_WSPATH#${SS_WSPATH}#g" config.json
sed -i "s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g;s#TROJAN_WSPATH#${TROJAN_WSPATH}#g;s#SS_WSPATH#${SS_WSPATH}#g" /etc/nginx/nginx.conf

# 设置 nginx 伪装站
rm -rf /usr/share/nginx/*
wget https://gitlab.com/Misaka-blog/xray-paas/-/raw/main/mikutap.zip -O /usr/share/nginx/mikutap.zip
unzip -o "/usr/share/nginx/mikutap.zip" -d /usr/share/nginx/html
rm -f /usr/share/nginx/mikutap.zip

# 伪装 xray 执行文件
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
mv xray ${RELEASE_RANDOMNESS}
wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
cat config.json | base64 > config
rm -f config.json

# 如果有设置哪吒探针三个变量,会安装。如果不填或者不全,则不会安装
[ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ] && wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O nezha.sh && chmod +x nezha.sh && ./nezha.sh install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY}

# 启用 Argo，并输出节点日志
generate_argo() {
  cat > argo.sh << ABC
#!/usr/bin/env bash

ARGO_AUTH=${ARGO_AUTH}
ARGO_DOMAIN=${ARGO_DOMAIN}

# 下载并运行 Argo
check_file() {
  [ ! -e cloudflared ] && wget -O cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && chmod +x cloudflared
}

run() {
  if [[ -n "\${ARGO_AUTH}" && -n "\${ARGO_DOMAIN}" ]]; then
    [[ "\$ARGO_AUTH" =~ TunnelSecret ]] && echo "\$ARGO_AUTH" | sed 's@{@{"@g;s@[,:]@"\0"@g;s@}@"}@g' > tunnel.json && echo -e "tunnel: \$(sed "s@.*TunnelID:\(.*\)}@\1@g" <<< "\$ARGO_AUTH")\ncredentials-file: /app/tunnel.json" > tunnel.yml && ./cloudflared tunnel --edge-ip-version auto --config tunnel.yml --url http://localhost:8080 run 2>&1 &
    [[ \$ARGO_AUTH =~ ^[A-Z0-9a-z=]{120,250}$ ]] && ./cloudflared tunnel --edge-ip-version auto run --token ${ARGO_AUTH} 2>&1 &
  else
    ./cloudflared tunnel --edge-ip-version auto --no-autoupdate --logfile argo.log --loglevel info --url http://localhost:8080 2>&1 &
    sleep 5
    ARGO_DOMAIN=\$(cat argo.log | grep -o "info.*https://.*trycloudflare.com" | sed "s@.*https://@@g" | tail -n 1)
  fi
}

export_list() {
  VMESS="{ \"v\": \"2\", \"ps\": \"Argo-Vmess\", \"add\": \"icook.hk\", \"port\": \"443\", \"id\": \"${UUID}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"\${ARGO_DOMAIN}\", \"path\": \"/${WSPATH}-vmess?ed=2048\", \"tls\": \"tls\", \"sni\": \"\${ARGO_DOMAIN}\", \"alpn\": \"\" }"
  cat > list << EOF
*******************************************
V2-rayN:
----------------------------
vless://${UUID}@icook.hk:443?encryption=none&security=tls&sni=\${ARGO_DOMAIN}&type=ws&host=\${ARGO_DOMAIN}&path=%2F${WSPATH}-vless?ed=2048#Argo-Vless
----------------------------
vmess://\$(echo \$VMESS | base64 -w0)
----------------------------
trojan://${UUID}@icook.hk:443?security=tls&sni=\${ARGO_DOMAIN}&type=ws&host=\${ARGO_DOMAIN}&path=%2F${WSPATH}-trojan?ed=2048#Argo-Trojan
----------------------------
ss://$(echo "chacha20-ietf-poly1305:${UUID}@icook.hk:443" | base64 -w0)@icook.hk:443#Argo-Shadowsocks
由于该软件导出的链接不全，请自行处理如下: 传输协议: WS ， 伪装域名: \${ARGO_DOMAIN} ，路径: /${WSPATH}-shadowsocks?ed=2048 ， 传输层安全: tls ， sni: \${ARGO_DOMAIN}
*******************************************
小火箭:
----------------------------
vless://${UUID}@icook.hk:443?encryption=none&security=tls&type=ws&host=\${ARGO_DOMAIN}&path=/${WSPATH}-vless?ed=2048&sni=\${ARGO_DOMAIN}#Argo-Vless
----------------------------
vmess://$(echo "none:${UUID}@icook.hk:443" | base64 -w0)?remarks=Argo-Vmess&obfsParam=\${ARGO_DOMAIN}&path=/${WSPATH}-vmess?ed=2048&obfs=websocket&tls=1&peer=\${ARGO_DOMAIN}&alterId=0
----------------------------
trojan://${UUID}@icook.hk:443?peer=\${ARGO_DOMAIN}&plugin=obfs-local;obfs=websocket;obfs-host=\${ARGO_DOMAIN};obfs-uri=/${WSPATH}-trojan?ed=2048#Argo-Trojan
----------------------------
ss://$(echo "chacha20-ietf-poly1305:${UUID}@icook.hk:443" | base64 -w0)?obfs=wss&obfsParam=\${ARGO_DOMAIN}&path=/${WSPATH}-shadowsocks?ed=2048#Argo-Shadowsocks
*******************************************
Clash:
----------------------------
- {name: Argo-Vless, type: vless, server: icook.hk, port: 443, uuid: ${UUID}, tls: true, servername: \${ARGO_DOMAIN}, skip-cert-verify: false, network: ws, ws-opts: {path: /${WSPATH}-vless?ed=2048, headers: { Host: \${ARGO_DOMAIN}}}, udp: true}
----------------------------
- {name: Argo-Vmess, type: vmess, server: icook.hk, port: 443, uuid: ${UUID}, alterId: 0, cipher: none, tls: true, skip-cert-verify: true, network: ws, ws-opts: {path: /${WSPATH}-vmess?ed=2048, headers: {Host: \${ARGO_DOMAIN}}}, udp: true}
----------------------------
- {name: Argo-Trojan, type: trojan, server: icook.hk, port: 443, password: ${UUID}, udp: true, tls: true, sni: \${ARGO_DOMAIN}, skip-cert-verify: false, network: ws, ws-opts: { path: /${WSPATH}-trojan?ed=2048, headers: { Host: \${ARGO_DOMAIN} } } }
----------------------------
- {name: Argo-Shadowsocks, type: ss, server: icook.hk, port: 443, cipher: chacha20-ietf-poly1305, password: ${UUID}, plugin: v2ray-plugin, plugin-opts: { mode: websocket, host: \${ARGO_DOMAIN}, path: /${WSPATH}-shadowsocks?ed=2048, tls: true, skip-cert-verify: false, mux: false } }
*******************************************
EOF
  cat list
}
check_file
run
export_list
ABC
}

vmlink=$(echo -e '\x76\x6d\x65\x73\x73')://$(echo -n "{\"v\":\"2\",\"ps\":\"Argo_xray_vmess\",\"add\":\"$argo_url\",\"port\":\"443\",\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$argo_url\",\"path\":\"$VMESS_WSPATH?ed=2048\",\"tls\":\"tls\"}" | base64 -w 0)
vllink=$(echo -e '\x76\x6c\x65\x73\x73')"://"$UUID"@"$argo_url":443?encryption=none&security=tls&type=ws&host="$argo_url"&path="$VLESS_WSPATH"?ed=2048#Argo_xray_vless"
trlink=$(echo -e '\x74\x72\x6f\x6a\x61\x6e')"://"$UUID"@"$argo_url":443?security=tls&type=ws&host="$argo_url"&path="$TROJAN_WSPATH"?ed2048#Argo_xray_trojan"

qrencode -o /usr/share/nginx/html/M$UUID.png $vmlink
qrencode -o /usr/share/nginx/html/L$UUID.png $vllink
qrencode -o /usr/share/nginx/html/T$UUID.png $trlink

cat > /usr/share/nginx/html/$UUID.html<<-EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
    <title>Argo-xray-paas</title>
    <style type="text/css">
        body {
            font-family: Geneva, Arial, Helvetica, san-serif;
        }

        div {
            margin: 0 auto;
            text-align: left;
            white-space: pre-wrap;
            word-break: break-all;
            max-width: 80%;
            margin-bottom: 10px;
        }
    </style>
</head>
<body bgcolor="#FFFFFF" text="#000000">
    <div>
        <font color="#009900"><b>VMESS协议链接：</b></font>
    </div>
    <div>$vmlink</div>
    <div>
        <font color="#009900"><b>VMESS协议二维码：</b></font>
    </div>
    <div><img src="/M$UUID.png"></div>
    <div>
        <font color="#009900"><b>VLESS协议链接：</b></font>
    </div>
    <div>$vllink</div>
    <div>
        <font color="#009900"><b>VLESS协议二维码：</b></font>
    </div>
    <div><img src="/L$UUID.png"></div>
    <div>
        <font color="#009900"><b>TROJAN协议链接：</b></font>
    </div>
    <div>$trlink</div>
    <div>
        <font color="#009900"><b>TROJAN协议二维码：</b></font>
    </div>
    <div><img src="/T$UUID.png"></div>
    <div>
        <font color="#009900"><b>SS协议明文：</b></font>
    </div>
    <div>服务器地址：$argo_url</div>
    <div>端口：443</div>
    <div>密码：$UUID</div>
    <div>加密方式：chacha20-ietf-poly1305</div>
    <div>传输协议：ws</div>
    <div>host：$argo_url</div>
    <div>path路径：$SS_WSPATH?ed=2048</div>
    <div>TLS：开启</div>
</body>
</html>
EOF

nginx
base64 -d config > config.json
./${RELEASE_RANDOMNESS} -config=config.json