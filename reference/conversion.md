# Conversão — referência

Categoria `conversion` · 15 scripts · 3 com `--json` · 9 com `--dry-run`.

PDF, DOCX, XLSX, Markdown, imagem, áudio e vídeo.

Invocação: `dogu <script> [flags]` (o `.sh` é opcional). Contrato completo de
flags: `dogu <script> --help`.

## base64-tool.sh — Codifica/decodifica Base64, URL encode, hex

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `xxd` + `python3`
- Exemplo: `dogu base64-tool -e 'Hello World'`
- Flags: `--encode, -e (string)` Codifica em Base64 · `--decode, -d (string)` Decodifica de Base64 ·
  `--url-encode (string)` Codifica para URL · `--url-decode (string)` Decodifica de URL ·
  `--hex-encode (string)` Codifica para hexadecimal ·
  `--hex-decode (string)` Decodifica de hexadecimal ·
  `--file (string)` Usa conteudo de arquivo como input

## color-converter.sh — Conversao entre HEX, RGB, HSL e nome de cor + preview

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `bc`
- Exemplo: `dogu color-converter -c '#FF5733' --preview`
- Flags: `--color, -c (string)` Cor a converter (HEX, RGB, HSL ou nome) ·
  `--preview (bool)` Mostra preview da cor no terminal ·
  `--list (bool)` Lista nomes de cores conhecidos

## currency-converter.sh — Cotacao de moedas em tempo real via API

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `curl`
- Exemplo: `dogu currency-converter -f USD -t BRL -a 100`
- Flags: `--from, -f (string)` Moeda de origem · `--to, -t (string)` Moeda de destino ·
  `--amount, -a (string)` Valor a converter · `--list (bool)` Lista moedas populares

## docx-to-md.sh — Converte arquivos .docx para Markdown via pandoc

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `pandoc`
- Exemplo: `dogu docx-to-md relatorio.docx`
- Flags: `--output, -o (string)` Diretorio de saida ·
  `--recursive, -r (bool)` Converte todos os .docx em um diretorio ·
  `--suffix, -s (string)` Sufixo opcional antes de .md ·
  `--overwrite (bool)` Sobrescreve .md existentes

## image-optimizer.sh — Redimensiona e comprime imagens em lote

- Risco: `dry-run-ok` · JSON: sim · Dry-run: sim · Interativo: não
- Dependências: `convert`
- Exemplo: `dogu image-optimizer -r ./fotos -o ./web -f webp`
- Flags: `--output, -o (string)` Diretorio de saida · `--recursive, -r (bool)` Varre subdiretorios ·
  `--quality, -q (int)` Qualidade (1-100) · `--max-width (int)` Largura maxima em pixels ·
  `--format, -f (string)` keep, jpg, png ou webp · `--force (bool)` Sobrescreve a saida

## jpg-to-text.sh — Extrai texto de imagens JPG via OCR

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `tesseract`
- Exemplo: `dogu jpg-to-text -l por+eng foto.jpg`
- Flags: `--lang, -l (string)` Idioma do OCR · `--output, -o (string)` Salva saida em arquivo .txt ·
  `--preprocess, -p (bool)` Aplica pre-processamento

## json-yaml-tool.sh — Valida, formata, consulta e converte JSON/YAML

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `jq` + `python3` · Python: `pyyaml`
- Exemplo: `dogu json-yaml-tool --to-yaml config.json`
- Flags: `--validate (bool)` Valida o arquivo · `--format (bool)` Formata o arquivo ·
  `--query (string)` Aplica expressao jq · `--to-yaml (bool)` Converte JSON para YAML ·
  `--to-json (bool)` Converte YAML para JSON · `--output, -o (string)` Arquivo de saida

## md-to-pdf.sh — Converte Markdown para PDF usando pandoc + XeLaTeX

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `pandoc` + `xelatex` + `rsvg-convert`
- Exemplo: `dogu md-to-pdf documento.md`

## pdf-merge.sh — Junta varios PDFs em um unico arquivo

- Risco: `dry-run-ok` · JSON: sim · Dry-run: sim · Interativo: não
- Dependências: `pdfunite` + `pdfinfo`
- Exemplo: `dogu pdf-merge -o contrato.pdf parte1.pdf parte2.pdf`
- Flags: `--output, -o (string)` Arquivo de saida · `--force (bool)` Sobrescreve a saida

## pdf-split.sh — Divide um PDF em paginas ou intervalos

- Risco: `dry-run-ok` · JSON: sim · Dry-run: sim · Interativo: não
- Dependências: `pdfseparate` + `pdfunite` + `pdfinfo`
- Exemplo: `dogu pdf-split --pages 1-3,7 documento.pdf`
- Flags: `--pages, -p (string)` Intervalos: 1-3,5,7- · `--output, -o (string)` Diretorio de saida ·
  `--prefix (string)` Prefixo dos arquivos · `--force (bool)` Sobrescreve arquivos

## pdf-to-jpg.sh — Converte arquivos .pdf em imagens JPG

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `pdftoppm` + `pdfinfo`
- Exemplo: `dogu pdf-to-jpg -q 90 -r 300 documento.pdf`
- Flags: `--output, -o (string)` Diretorio de saida · `--quality, -q (int)` Qualidade JPEG 1-100 ·
  `--resolution, -r (int)` Resolucao em DPI · `--prefix, -p (string)` Prefixo para arquivos de saida ·
  `--single-page, -s (int)` Extrai apenas uma pagina · `--first-page, -f (int)` Primeira pagina ·
  `--last-page, -l (int)` Ultima pagina

## pdf-to-md.sh — Converte arquivos .pdf para Markdown extraindo o texto

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `pdftotext` · opcional: `pdftoppm` + `tesseract`
- Exemplo: `dogu pdf-to-md -r --ocr ~/Documents`
- Flags: `--output, -o (string)` Diretorio de saida ·
  `--recursive, -r (bool)` Converte todos os .pdf em um diretorio ·
  `--suffix, -s (string)` Sufixo antes de .md ·
  `--keep-page-breaks (bool)` Mantem separadores de pagina ·
  `--ocr (bool)` Usa OCR quando o PDF nao tiver texto · `--ocr-lang (string)` Idioma do OCR ·
  `--overwrite (bool)` Sobrescreve .md existentes

## ris-to-csv.sh — Converte arquivos .ris (citacoes bibliograficas) para CSV

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Exemplo: `dogu ris-to-csv -r -m ~/referencias`
- Flags: `--output, -o (string)` Diretorio de saida ·
  `--recursive, -r (bool)` Converte todos os .ris recursivamente ·
  `--merge, -m (bool)` Combina todos num unico CSV ·
  `--delimiter, -d (string)` Separador dos campos CSV · `--fields, -f (string)` Campos a exportar ·
  `--all-fields, -a (bool)` Exporta todas as tags · `--no-header (bool)` Nao escreve cabecalho ·
  `--overwrite (bool)` Sobrescreve .csv existentes

## unit-converter.sh — Conversao entre unidades de medida

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `bc`
- Exemplo: `dogu unit-converter -t length -f km -i 100`
- Flags: `--type, -t (string)` Tipo de conversao: temp, length, weight, volume, speed, area, time ·
  `--from, -f (string)` Unidade de origem · `--input, -i (string)` Valor a converter ·
  `--list (bool)` Lista unidades disponiveis

## xlsx-to-csv.sh — Converte arquivos .xlsx para CSV, extraindo cada aba em arquivo separado

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `python3` · Python: `openpyxl`
- Exemplo: `dogu xlsx-to-csv dados.xlsx`
- Flags: `--output, -o (string)` Diretorio de saida ·
  `--recursive, -r (bool)` Converte todos os .xlsx recursivamente ·
  `--delimiter, -d (string)` Separador dos campos CSV ·
  `--sheet, -S (string)` Extrai apenas a aba especificada ·
  `--always-suffix (bool)` Usa sufixo de aba mesmo com uma aba ·
  `--overwrite (bool)` Sobrescreve .csv existentes
