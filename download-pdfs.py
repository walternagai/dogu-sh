#!/usr/bin/env python3
"""
download-pdfs.py — Baixa PDFs de artigos acadêmicos a partir de uma lista de URLs.

Suporte: IEEE Xplore, ACM, Springer, ScienceDirect, Scopus, e fallback genérico.
Baixa apenas conteúdo publicamente acessível (open access).

Uso:
    python3 download-pdfs.py urls.txt
    python3 download-pdfs.py urls.txt --outdir ./meus_pdfs

Formato do arquivo de entrada: uma URL por linha.
"""

import re
import sys
import time
import argparse
import urllib.request
import urllib.parse
import urllib.error
from pathlib import Path
from html.parser import HTMLParser

USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
)
REQUEST_TIMEOUT = 30
DELAY_BETWEEN_REQUESTS = 2


class LinkExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag == "a":
            href = dict(attrs).get("href")
            if href:
                self.links.append(href)


def strip_fragment(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    if parsed.fragment:
        return urllib.parse.urlunparse(parsed._replace(fragment=""))
    return url


def sanitize_filename(name: str) -> str:
    name = re.sub(r'[<>:"/\\|?*]', "_", name)
    name = re.sub(r"\s+", " ", name).strip()
    name = name.replace(" ", "_")
    return name[:200]


def extract_links(html: str) -> list[str]:
    parser = LinkExtractor()
    parser.feed(html)
    return parser.links


def absolute_links(html: str, base_url: str) -> list[str]:
    return [
        strip_fragment(urllib.parse.urljoin(base_url, link))
        for link in extract_links(html)
    ]


def build_request(url: str) -> urllib.request.Request:
    return urllib.request.Request(
        url, headers={"User-Agent": USER_AGENT, "Accept": "text/html,application/pdf,*/*"}
    )


def http_get(url: str) -> tuple[str | None, str | None]:
    """GET e retorna (html, final_url). Retorna (None, None) em erro."""
    try:
        with urllib.request.urlopen(
            build_request(url), timeout=REQUEST_TIMEOUT
        ) as resp:
            final_url = resp.geturl()
            ct = resp.headers.get("Content-Type", "")
            if "text/html" not in ct and "application/xhtml" not in ct:
                return None, None
            charset = "utf-8"
            for part in ct.split(";"):
                part = part.strip()
                if part.lower().startswith("charset="):
                    charset = part.split("=", 1)[1].strip()
                    break
            return resp.read().decode(charset, errors="replace"), final_url
    except (urllib.error.URLError, urllib.error.HTTPError, OSError, ValueError) as e:
        print(f"  [erro HTTP] {e}", file=sys.stderr)
        return None, None


def probe_url(url: str) -> str | None:
    """Checa o Content-Type de uma URL via GET com Range bytes=0-0.
    Retorna o Content-Type se acessível, None caso contrário."""
    req = urllib.request.Request(
        strip_fragment(url),
        headers={
            "User-Agent": USER_AGENT,
            "Range": "bytes=0-0",
            "Accept": "application/pdf,text/html,*/*",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            return resp.headers.get("Content-Type", "")
    except Exception:
        return None


def try_template_urls(template_urls: list[str]) -> str | None:
    """Tenta uma lista de URLs candidatas; retorna a primeira que devolve
    Content-Type de PDF (ou não-HTML)."""
    for url in template_urls:
        ct = probe_url(url)
        if ct is None:
            continue
        ct_lower = ct.lower()
        if "pdf" in ct_lower:
            return url
        if "html" not in ct_lower and "javascript" not in ct_lower:
            return url
    return None


def find_pdf_links(html: str, base_url: str) -> list[str]:
    links = absolute_links(html, base_url)
    return [
        link
        for link in links
        if urllib.parse.urlparse(link).path.lower().endswith(".pdf")
        or ".pdf?" in link.lower()
    ]


def resolve_ieeexplore(url: str) -> str | None:
    m = re.search(r"(?:document|arnumber)[=/](\d+)", url)
    if not m:
        return None
    doc_id = m.group(1)
    candidates = [
        f"https://ieeexplore.ieee.org/stampPDF/getPDF.jsp?arnumber={doc_id}",
        f"https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber={doc_id}",
    ]
    return try_template_urls(candidates)


def resolve_acm(url: str, html: str, final_url: str) -> str | None:
    doi = None
    for pattern in [
        r"doi/(?:full/|abs/|pdf/)?(10\.\d{4,}/[^\s?&]+)",
        r"(10\.\d{4,}/[^\s?&]+)",
    ]:
        m = re.search(pattern, url)
        if m:
            doi = m.group(1).rstrip(".»\"'")
            break

    if doi:
        candidates = [
            f"https://dl.acm.org/doi/pdf/{doi}",
            f"https://dl.acm.org/doi/pdf/{doi}?download=true",
        ]
        result = try_template_urls(candidates)
        if result:
            return result

    for link in absolute_links(html, final_url):
        parsed = urllib.parse.urlparse(link)
        if parsed.path.lower().endswith(".pdf"):
            ct = probe_url(link)
            if ct and "pdf" in ct.lower():
                return link
    return None


def resolve_springer(url: str) -> str | None:
    m = re.search(r"article/(10\.\d{4,}/[^\s?&]+)", url)
    if not m:
        m = re.search(r"(10\.\d{4,}/[^\s?&]+)", url)
    if not m:
        return None
    doi = m.group(1).rstrip(".»\"'")
    candidates = [
        f"https://link.springer.com/content/pdf/{doi}.pdf",
        f"https://link.springer.com/content/pdf/{doi}",
    ]
    return try_template_urls(candidates)


def resolve_sciencedirect(url: str, html: str, final_url: str) -> str | None:
    m = re.search(r"pii/([A-Z0-9]+)", url)
    if m:
        pii = m.group(1)
        candidates = [
            f"https://www.sciencedirect.com/science/article/pii/{pii}/pdfft",
            f"https://www.sciencedirect.com/science/article/pii/{pii}/pdf",
        ]
        result = try_template_urls(candidates)
        if result:
            return result

    m2 = re.search(r'"pdfDownloadUrl":\s*"([^"]+)"', html)
    if m2:
        return strip_fragment(urllib.parse.urljoin(final_url, m2.group(1)))

    for link in absolute_links(html, final_url):
        parsed = urllib.parse.urlparse(link)
        if parsed.path.lower().endswith(".pdf"):
            ct = probe_url(link)
            if ct and "pdf" in ct.lower():
                return link
    return None


def resolve_vilniustech(url: str, html: str, final_url: str) -> str | None:
    pdfs = find_pdf_links(html, final_url)
    if pdfs:
        return pdfs[0]

    for link in absolute_links(html, final_url):
        if "/download/" not in link.lower() and "?format=pdf" not in link.lower():
            continue
        ct = probe_url(link)
        if ct and "pdf" in ct.lower():
            return link
    return None


def resolve_scopus(_url: str) -> str | None:
    return None


def resolve_generic(url: str, html: str, final_url: str) -> str | None:
    pdfs = find_pdf_links(html, final_url)
    if pdfs:
        return pdfs[0]

    for link in absolute_links(html, final_url):
        low = link.lower()
        if any(kw in low for kw in ["download", "/pdf/", "pdfdownload", "?format=pdf"]):
            ct = probe_url(link)
            if ct and "pdf" in ct.lower():
                return link
    return None


DOMAIN_HANDLERS = [
    (re.compile(r"ieeexplore\.ieee\.org"), resolve_ieeexplore, False),
    (re.compile(r"dl\.acm\.org"), resolve_acm, True),
    (re.compile(r"link\.springer\.com"), resolve_springer, False),
    (re.compile(r"sciencedirect\.com"), resolve_sciencedirect, True),
    (re.compile(r"journals\.vilniustech\.lt"), resolve_vilniustech, True),
    (re.compile(r"scopus\.com"), resolve_scopus, False),
]


def find_pdf_url(url: str) -> tuple[str | None, str | None]:
    for pattern, handler, needs_html in DOMAIN_HANDLERS:
        if pattern.search(url):
            if needs_html:
                html, final_url = http_get(url)
                if not html:
                    return None, pattern.pattern
                return handler(url, html, final_url), pattern.pattern
            return handler(url), pattern.pattern

    html, final_url = http_get(url)
    if not html:
        return None, None
    return resolve_generic(url, html, final_url), None


def extract_id_from_url(url: str) -> str:
    m = re.search(r"document/(\d+)", url)
    if m:
        return f"ieee_{m.group(1)}"

    m = re.search(r"doi/(?:full/|abs/|pdf/)?(10\.\d{4,}/([^\s?&]+))", url)
    if m:
        slug = re.sub(r"[^a-zA-Z0-9._-]", "_", m.group(2))
        return slug[:80]

    m = re.search(r"article/(10\.\d{4,}/([^\s?&]+))", url)
    if m:
        slug = re.sub(r"[^a-zA-Z0-9._-]", "_", m.group(2))
        return slug[:80]

    m = re.search(r"pii/([A-Z0-9]+)", url)
    if m:
        return f"sciencedirect_{m.group(1)}"

    m = re.search(r"article/view/(\d+)", url)
    if m:
        return f"vilnius_{m.group(1)}"

    m = re.search(r"publications/(\d+)", url)
    if m:
        return f"scopus_{m.group(1)}"

    parsed = urllib.parse.urlparse(url)
    path = parsed.path.strip("/")
    if path:
        parts = path.split("/")
        return sanitize_filename(parts[-1] if parts[-1] else parts[-2])
    return "document"


def download_pdf(pdf_url: str, outdir: Path, filename: str) -> bool:
    outdir.mkdir(parents=True, exist_ok=True)
    filepath = outdir / f"{filename}.pdf"

    if filepath.exists():
        print(f"  [pula] ja existe: {filepath.name}")
        return True

    try:
        with urllib.request.urlopen(
            build_request(strip_fragment(pdf_url)), timeout=REQUEST_TIMEOUT
        ) as resp:
            ct = (resp.headers.get("Content-Type") or "").lower()
            if "pdf" not in ct and (
                "html" in ct
                or "javascript" in ct
                or "json" in ct
            ):
                print(
                    f"  [falha] Content-Type={ct} (acesso restrito provavelmente)",
                    file=sys.stderr,
                )
                return False
            data = resp.read()
    except urllib.error.HTTPError as e:
        print(f"  [erro] HTTP {e.code} (acesso restrito)", file=sys.stderr)
        return False
    except (urllib.error.URLError, OSError) as e:
        print(f"  [erro download] {e}", file=sys.stderr)
        return False

    if data.startswith(b"%PDF"):
        filepath.write_bytes(data)
        size_kb = len(data) / 1024
        print(f"  [ok] {filepath.name}  ({size_kb:.0f} KB)")
        return True

    if data[:200].strip().startswith(b"<!") or b"<html" in data[:500].lower():
        print(
            f"  [falha] resposta HTML (acesso restrito provavelmente)",
            file=sys.stderr,
        )
        return False

    filepath.write_bytes(data)
    size_kb = len(data) / 1024
    print(f"  [ok?] {filepath.name}  ({size_kb:.0f} KB - conteudo nao verificado)")
    return True


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Baixa PDFs de artigos academicos a partir de uma lista de URLs."
    )
    parser.add_argument("input", help="Arquivo texto com URLs (uma por linha)")
    parser.add_argument(
        "--outdir", default="./pdfs", help="Diretorio de saida (default: ./pdfs)"
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=DELAY_BETWEEN_REQUESTS,
        help=f"Atraso entre requisicoes em segundos (default: {DELAY_BETWEEN_REQUESTS})",
    )
    args = parser.parse_args()

    inpath = Path(args.input)
    if not inpath.is_file():
        print(f"Erro: arquivo nao encontrado: {args.input}", file=sys.stderr)
        sys.exit(1)

    urls = []
    for line in inpath.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            urls.append(line)

    if not urls:
        print("Nenhuma URL encontrada no arquivo.", file=sys.stderr)
        sys.exit(1)

    outdir = Path(args.outdir)
    total = len(urls)
    ok = 0
    fail = 0
    skip = 0

    print(f"Processando {total} URLs... Saida: {outdir.resolve()}")
    print("-" * 60)

    for i, url in enumerate(urls, 1):
        print(f"\n[{i}/{total}] {url}")

        host = urllib.parse.urlparse(url).hostname or ""
        if "scopus.com" in host:
            print("  [ignora] Scopus nao fornece PDF publico")
            skip += 1
            continue

        pdf_url, _label = find_pdf_url(url)

        if not pdf_url:
            print("  [falha] PDF nao encontrado (pode ser acesso restrito)")
            fail += 1
        else:
            name = extract_id_from_url(url)
            if download_pdf(pdf_url, outdir, name):
                ok += 1
            else:
                fail += 1

        if i < total:
            time.sleep(args.delay)

    print("\n" + "=" * 60)
    print(
        f"Concluido: {ok} ok, {fail} falhas, {skip} ignorados (de {total})"
    )
    print(f"Arquivos salvos em: {outdir.resolve()}")


if __name__ == "__main__":
    main()
