# Rede — referência

Categoria `network` · 10 scripts · 4 com `--json` · 2 com `--dry-run`.

DNS, HTTP, portas, SSL, Wi-Fi, SSH, speedtest e túneis.

Invocação: `dogu <script> [flags]` (o `.sh` é opcional). Contrato completo de
flags: `dogu <script> --help`.

## api-tester.sh — Teste rapido de APIs REST com formatacao JSON

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `curl`
- Exemplo: `dogu api-tester -u https://api.example.com/users -X GET`
- Flags: `--url, -u (string)` URL da requisicao ·
  `--method, -X (string)` Metodo HTTP (GET, POST, PUT, DELETE, PATCH, HEAD) ·
  `--data, -d (string)` Corpo da requisicao · `--header, -H (string)` Cabecalho personalizado ·
  `--verbose, -v (bool)` Mostra cabecalhos e metadados ·
  `--status-only (bool)` Mostra apenas o codigo de status

## dns-lookup.sh — Lookup DNS (A, AAAA, MX, NS, TXT, CNAME)

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `dig` + `nslookup`
- Exemplo: `dogu dns-lookup -d example.com -t MX`
- Flags: `--domain, -d (string)` Dominio para consultar · `--type, -t (string)` Tipo de registro ·
  `--all (bool)` Consulta todos os tipos comuns · `--server (string)` Servidor DNS especifico

## http-server.sh — Servidor HTTP local para um diretorio

- Risco: `read-only` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `python3`
- Exemplo: `dogu http-server -d ./public -p 8080`
- Flags: `--directory, -d (string)` Diretorio a servir · `--port, -p (int)` Porta (padrao: 8000) ·
  `--bind, -b (string)` Endereco de escuta

## ip-info.sh — Info do IP publico, ISP e localizacao geografica

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `curl` + `jq`
- Exemplo: `dogu ip-info --json`
- Flags: `--local, -l (bool)` Mostra IP local · `--public, -p (bool)` Mostra apenas IP publico

## port-check.sh — Verifica se portas estao abertas em um host

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `bc` + `nc`
- Exemplo: `dogu port-check -h google.com -p 80,443`
- Flags: `--host, -h (string)` Host para verificar · `--port, -p (string)` Porta ou range ·
  `--common (bool)` Verifica portas comuns · `--timeout (int)` Timeout em milissegundos

## speedtest-log.sh — Executa testes de velocidade e mantem historico em CSV

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `speedtest-cli`
- Exemplo: `dogu speedtest-log --run`
- Flags: `--run, -r (bool)` Executa um teste agora · `--history, -h (bool)` Mostra historico ·
  `--today, -t (bool)` Mostra apenas resultados de hoje · `--chart, -c (bool)` Mostra grafico ASCII ·
  `--csv (bool)` Exporta historico como CSV · `--output, -o (string)` Diretorio para dados

## ssh-tunnel-mgr.sh — Gerenciador de tuneis SSH

- Risco: `read-only` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `ssh`
- Exemplo: `dogu ssh-tunnel-mgr --create 8080 localhost 80 user@server`
- Flags: `--create, -l (string)` Cria tunel local · `--remote, -r (string)` Cria tunel reverso ·
  `--daemon, -d (bool)` Executa o tunel em segundo plano · `--list (bool)` Lista tuneis SSH ativos ·
  `--stop (string)` Encerra tunel na porta especificada

## subnet-calc.sh — Calculadora de sub-redes IPv4/CIDR

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `bc`
- Exemplo: `dogu subnet-calc -i 192.168.1.0/24`
- Flags: `--ip, -i (string)` Calcula sub-rede a partir do IP/CIDR

## whois.sh — Consulta WHOIS de dominios

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `whois`
- Exemplo: `dogu whois -d example.com`
- Flags: `--domain, -d (string)` Dominio para consultar · `--raw, -r (bool)` Saida bruta do whois

## wifi-scanner.sh — Escaneia redes Wi-Fi e sugere o melhor canal

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `nmcli` + `iwlist`
- Exemplo: `dogu wifi-scanner`
