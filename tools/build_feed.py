"""Builds the Gaza Now news API (news.json) from trusted outlets' RSS feeds.

Runs on GitHub Actions every 30 minutes. Output schema:
{
  "generated": "2026-11-22T20:00:00Z",
  "sources": [{"id", "name", "ok", "count"}],
  "articles": [{"link", "title", "summary", "sourceId", "publisher", "imageUrl",
                "published", "category", "isGaza"}]
}
"""
import concurrent.futures as cf
import email.utils
import html
import json
import os
import re
import sys
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

UA = "Mozilla/5.0 (Linux; Android 14) GazaNow-API/1.0"

SOURCES = [
    ("aljazeera", "الجزيرة نت", "https://www.aljazeera.net/aljazeerarss/a7c186be-1baa-4bd4-9d80-a84db769f779/73d0e1b4-532f-45ef-b135-bfdff8b8cab9"),
    ("un", "أخبار الأمم المتحدة", "https://news.un.org/feed/subscribe/ar/news/all/rss.xml"),
    ("bbc", "بي بي سي عربي", "https://feeds.bbci.co.uk/arabic/middleeast/rss.xml"),
    ("france24", "فرانس 24", "https://www.france24.com/ar/%D8%A7%D9%84%D8%B4%D8%B1%D9%82-%D8%A7%D9%84%D8%A3%D9%88%D8%B3%D8%B7/rss"),
    ("aa", "الأناضول", "https://www.aa.com.tr/ar/rss/default?cat=guncel"),
    ("skynews", "سكاي نيوز عربية", "https://www.skynewsarabia.com/rss"),
    ("dw", "DW عربية", "https://rss.dw.com/rdf/rss-ar-all"),
]

GAZA = ["غزة", "غزّة", "فلسطين", "الفلسطيني", "فلسطيني", "رفح", "خان يونس", "خانيونس", "دير البلح",
        "جباليا", "النصيرات", "بيت لاهيا", "بيت حانون", "الأونروا", "الضفة الغربية", "القدس", "المغازي", "البريج"]


def get(url, timeout=20):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Language": "ar"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", errors="replace")


def local(tag):
    return tag.rsplit("}", 1)[-1]


def child(el, name):
    for c in el:
        if local(c.tag) == name:
            return c
    return None


def text(el, name):
    c = child(el, name)
    if c is None:
        return ""
    return "".join(c.itertext()).strip()


def clean(s):
    s = re.sub(r"<[^>]*>", " ", s or "")
    s = html.unescape(s)
    return re.sub(r"\s+", " ", s).strip()


def upgrade(url):
    url = html.unescape(url)
    if "ichef.bbci.co.uk" in url:
        url = re.sub(r"/ws/\d+/", "/ws/800/", url)
    return url


def image_of(item, raw_html):
    for c in item:
        n, url = local(c.tag), c.get("url")
        if n in ("thumbnail", "content") and url and url.startswith("http"):
            return upgrade(url)
        if n == "enclosure" and url and (c.get("type") or "image").startswith("image"):
            return upgrade(url)
        if n == "image":
            t = "".join(c.itertext()).strip()
            if t.startswith("http"):
                return upgrade(t)
    m = re.search(r"""<img[^>]+src=["']([^"']+)["']""", raw_html or "", re.I)
    return upgrade(m.group(1)) if m else None


def parse_date(s):
    if not s:
        return None
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00")).astimezone(timezone.utc)
    except ValueError:
        pass
    try:
        return email.utils.parsedate_to_datetime(s).astimezone(timezone.utc)
    except (TypeError, ValueError):
        return None


def parse_feed(sid, name, body):
    root = ET.fromstring(body.encode("utf-8"))
    out = []
    for item in root.iter():
        if local(item.tag) not in ("item", "entry"):
            continue
        title = clean(text(item, "title"))
        link = text(item, "link") or (child(item, "link").get("href") if child(item, "link") is not None else "")
        if not title or not link.startswith("http"):
            continue
        raw = text(item, "description") or text(item, "summary") or text(item, "encoded")
        summary = clean(raw)
        date = parse_date(text(item, "pubDate") or text(item, "date") or text(item, "published") or text(item, "updated"))
        out.append({
            "link": link.strip(),
            "title": title,
            "summary": summary[:600] + ("…" if len(summary) > 600 else ""),
            "sourceId": sid,
            "publisher": None,
            "imageUrl": image_of(item, raw),
            "published": (date or datetime.now(timezone.utc)).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "category": clean(text(item, "category") or text(item, "subject")) or None,
        })
    return out


OG = [
    re.compile(r"""<meta[^>]+property=["']og:image["'][^>]*content=["']([^"']+)["']""", re.I),
    re.compile(r"""<meta[^>]+content=["']([^"']+)["'][^>]*property=["']og:image["']""", re.I),
]


def og_image(link):
    try:
        page = get(link, timeout=15)
    except Exception:
        return None
    for rx in OG:
        m = rx.search(page)
        if m:
            url = html.unescape(m.group(1))
            if "social-preview" in url or "logo" in url.lower():
                return None
            return url
    return None


def newsdata(key):
    q = urllib.parse.urlencode({"apikey": key, "language": "ar", "q": "غزة OR فلسطين OR رفح OR خانيونس", "removeduplicate": "1"})
    data = json.loads(get(f"https://newsdata.io/api/1/latest?{q}"))
    out = []
    for r in data.get("results") or []:
        if not r.get("title") or not str(r.get("link", "")).startswith("http"):
            continue
        d = parse_date((r.get("pubDate") or "").replace(" ", "T") + "Z")
        img = r.get("image_url")
        out.append({
            "link": r["link"], "title": clean(r["title"]), "summary": clean(r.get("description") or "")[:600],
            "sourceId": "api", "publisher": r.get("source_name") or r.get("source_id"),
            "imageUrl": img if img and str(img).startswith("http") else None,
            "published": (d or datetime.now(timezone.utc)).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "category": (r.get("category") or [None])[0],
        })
    return out


def main(out_path):
    articles, status = [], []

    def fetch(src):
        sid, name, url = src
        try:
            items = parse_feed(sid, name, get(url))
            return sid, name, items, None
        except Exception as e:  # noqa: BLE001
            return sid, name, [], str(e)

    with cf.ThreadPoolExecutor(8) as ex:
        for sid, name, items, err in ex.map(fetch, SOURCES):
            status.append({"id": sid, "name": name, "ok": err is None and bool(items), "count": len(items)})
            articles += items
            print(f"{name}: {len(items)} items" + (f" ERROR {err}" if err else ""))

    key = os.environ.get("NEWSDATA_API_KEY", "").strip()
    if key:
        try:
            extra = newsdata(key)
            articles += extra
            status.append({"id": "api", "name": "NewsData", "ok": True, "count": len(extra)})
        except Exception as e:  # noqa: BLE001
            status.append({"id": "api", "name": "NewsData", "ok": False, "count": 0})
            print("NewsData ERROR", e)

    seen, unique = set(), []
    for a in sorted(articles, key=lambda a: a["published"], reverse=True):
        if a["link"] in seen:
            continue
        seen.add(a["link"])
        a["isGaza"] = any(k in a["title"] + " " + a["summary"] for k in GAZA)
        unique.append(a)
    unique = unique[:250]

    # Fill in missing photos from each article page (Gaza stories first).
    missing = [a for a in unique if not a["imageUrl"]]
    missing.sort(key=lambda a: not a["isGaza"])
    with cf.ThreadPoolExecutor(16) as ex:
        for a, img in zip(missing, ex.map(lambda a: og_image(a["link"]), missing)):
            a["imageUrl"] = img

    with_img = sum(1 for a in unique if a["imageUrl"])
    print(f"TOTAL {len(unique)} articles, {with_img} with photos, {sum(a['isGaza'] for a in unique)} about Gaza")
    result = {
        "generated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "sources": status,
        "articles": unique,
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, separators=(",", ":"))
    if len(unique) < 20:
        sys.exit("Too few articles; keeping the previous news.json")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "news.json")
