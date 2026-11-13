# Segurança — referência

Categoria `security` · 5 scripts · 3 com `--json` · 2 com `--dry-run`.

Senhas, chaves SSH, segredos e certificados.

Invocação: `dogu <script> [flags]` (o `.sh` é opcional). Contrato completo de
flags: `dogu <script> --help`.

## env-keygen.sh — Gera chaves secretas seguras para uso em arquivos .env

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `openssl` · opcional: `uuidgen` + `xclip` + `xsel` + `python3`
- Exemplo: `dogu env-keygen -n SECRET_KEY -f hex -l 64`
- Flags: `--name, -n (string)` Nome da variavel · `--length, -l (int)` Tamanho em bytes ou caracteres ·
  `--format, -f (string)` Formato: hex, base64, uuid, alnum, etc. ·
  `--count, -c (int)` Gerar N chaves de uma vez · `--upper (bool)` Gerar em maiusculas ·
  `--copy (bool)` Copia a chave para a area de transferencia ·
  `--append (string)` Acrescenta a chave ao arquivo .env

## password-gen.sh — Gerador de senhas configuravel

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `bc`
- Exemplo: `dogu password-gen -l 32 -n 5`
- Flags: `--length, -l (int)` Comprimento da senha · `--count, -n (int)` Quantidade de senhas ·
  `--no-upper (bool)` Remove letras maiusculas · `--no-lower (bool)` Remove letras minusculas ·
  `--no-digits (bool)` Remove digitos · `--no-symbols (bool)` Remove simbolos ·
  `--only-hex (bool)` Apenas caracteres hexadecimais · `--passphrase (bool)` Gera passphrase ·
  `--check (string)` Verifica forca de senha

## secret-scanner.sh — Busca segredos expostos em codigo e configuracao (API keys, tokens, senhas)

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `grep`
- Exemplo: `dogu secret-scanner --json --severity high`
- Flags: `--path (string)` Caminho para escanear (padrao: .) ·
  `--type (string)` Tipo de segredo: all, api-key, password, token, private-key (padrao: all) ·
  `--severity (string)` Severidade minima: low, medium, high, critical (padrao: low) ·
  `--exclude (string)` Diretorio para excluir (pode ser repetido) ·
  `--fix (bool)` Exibe sugestoes detalhadas de correcao

## ssh-key-manager.sh — Gerencia chaves SSH (gerar, listar, rotacionar, distribuir)

- Risco: `dry-run-ok` · JSON: sim · Dry-run: sim · Interativo: não
- Dependências: `ssh-keygen` + `ssh-copy-id`
- Exemplo: `dogu ssh-key-manager --generate --type ed25519`
- Flags: `--generate (bool)` Gera nova chave SSH · `--list (bool)` Lista chaves existentes ·
  `--rotate (bool)` Rotaciona chave · `--deploy (string)` Distribui chave publica para host ·
  `--type (string)` Tipo de chave: ed25519 ou rsa · `--bits (int)` Bits para RSA ·
  `--comment (string)` Comentario da chave · `--key-path (string)` Caminho customizado da chave

## ssl-cert-check.sh — Verifica validade e emissor de certificado TLS

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `openssl`
- Exemplo: `dogu ssl-cert-check example.com --json`
- Flags: `--port, -p (int)` Porta (padrao: 443) · `--warn-days, -w (int)` Alerta em N dias
