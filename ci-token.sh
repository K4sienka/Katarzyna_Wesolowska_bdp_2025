#!/usr/bin/env bash
set -euo pipefail    # bez dodatkowych walidacji — jeśli chcesz, odkomentuj

TOKEN_URL="$ZITADEL_DOMAIN/oauth/v2/token"

SCOPES="openid urn:zitadel:iam:org:project:id:${PROJECT_ID}:aud urn:zitadel:iam:org:projects:roles urn:zitadel:iam:org:project:roles"

outer_json="$(printf '%s' "${STUDENT_KEY}" | base64 -d)"

kid="$(printf '%s' "$outer_json" | jq -r '.keyId // .kid')"
user_id="$(printf '%s' "$outer_json" | jq -r '.userId // .user_id // .sub // empty')"

pem="$(printf '%s' "$outer_json" | jq -r '
  if (.key != null and (.key | contains("-----BEGIN"))) then .key
  elif (.privateKey != null and (.privateKey | contains("-----BEGIN"))) then .privateKey
  else empty end
')"

if [ -z "$pem" ]; then
  inner_json="$(printf '%s' "$outer_json" | jq -r '.keyContent // empty' | base64 -d)"
  pem="$(printf '%s' "$inner_json" | jq -r '.key // .privateKey')"
fi

pem_file="$(mktemp)"
printf '%s' "$pem" > "$pem_file"

b64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

now="$(date +%s)"
exp="$((now + ASSERTION_TTL_SECONDS))"
jti="$(uuidgen)"

header_json=$(cat <<EOF
{"alg":"RS256","kid":"$kid","typ":"JWT"}
EOF
)
payload_json=$(cat <<EOF
{"iss":"$user_id","sub":"$user_id","aud":"$ZITADEL_DOMAIN","iat":$now,"exp":$exp,"jti":"$jti"}
EOF
)

header_b64="$(printf '%s' "$header_json" | b64url)"
payload_b64="$(printf '%s' "$payload_json" | b64url)"
signing_input="${header_b64}.${payload_b64}"

signature_b64="$(
  printf '%s' "$signing_input" \
  | openssl dgst -sha256 -sign "$pem_file" -binary \
  | b64url
)"

assertion="${signing_input}.${signature_b64}"

response="$(
  curl -s -X POST "$TOKEN_URL" \
    -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
    -d "scope=${SCOPES}" \
    -d "assertion=${assertion}"
)"

printf '%s\n' "$response"

rm -f "$pem_file"
