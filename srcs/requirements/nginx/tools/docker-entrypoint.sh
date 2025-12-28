ALREADY_EXISTS='false'

check_env() {
	i=0
	while read var; do
		content=$(eval "echo \${$var}")
		if [ -z "$content" ]; then
			echo "You need to specify $var"
			i=$((i+1))
		fi
	done << EOF
DOMAIN_NAME
EOF

	if [ $i -gt 0 ]; then
		exit 1
	fi
}

main() {
	if [ -f "/certs/cert.crt" ] && [ -f "/certs/cert.key" ]; then
		ALREADY_EXISTS='true'
	fi

	if [ "$ALREADY_EXISTS" = 'false' ]; then
		echo "Generating self-signed certificate..."
		openssl req -x509 -nodes -days 365 \
			-subj "/C=FR/ST=FR/O=42, School./CN=$DOMAIN_NAME" \
			-addext "subjectAltName=DNS:$DOMAIN_NAME" \
			-newkey rsa:4096 \
			-keyout /certs/cert.key \
			-out /certs/cert.crt;
		echo "Self-signed certificate generated."
	else
		echo "Certificate already exists"
	fi

	sed -i "s/DOMAIN_NAME/$DOMAIN_NAME/g" /etc/nginx/nginx.conf
}

main $@
exec $@
