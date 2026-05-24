#!/usr/bin/env python3
"""
Media rename helper — strips scene-release tags, applies Title Case.
Usage:
  python3 _rename_helper.py movie  "Annihilation (2018) [BluRay] [1080p] [YTS.AM]"
  python3 _rename_helper.py show   "Devs.S01.1080p.WEBRip.x265[eztv.re]"
  python3 _rename_helper.py upskill "vlsiTesting"
Prints the clean name to stdout.
"""
import re
import sys


def title_case(s: str) -> str:
    return " ".join(w.capitalize() for w in s.split())


# Everything from here onwards in a filename is release garbage
SCENE_CUTOFF = re.compile(
    r"[\s.\[(]("
    r"2160p|1080[pi]|720p|480p|4[Kk]|8[Kk]|"
    r"BluRay|BRRip|BrRip|WEBRip|WEB-DL|WebDL|HDRip|DVDRip|CAMRip|"
    r"NF|AMZN|DS4K|ATVP|HMAX|ZEE5|ITA|KOR|COMPLETE|DUAL.?AUDIO?|"
    r"x\.?264|x\.?265|HEVC|H\.?264|H\.?265|HDR10?|"
    r"AAC|DDP5?\.?1?|DD5\.1|AC3|EAC3|Atmos|"
    r"BONE|PSA|YIFY|afm72|MSubs?|ESubs?|iNTERNAL|eztv|rarbg|YTS|"
    r"TombDoc|LOKiHD|GalaxyTV|MULVAcoded|themoviesboss|KINGDOM_RG|"
    r"HashMiner|V3SP4EV3R|t3nzin|Judas|"
    r"Hindi|English|Korean|German|Italian|French|Japanese|Chinese|Spanish|"
    r"ORG|UNTOUCHED|REPACK|PROPER|Subs|Sub"
    r")",
    re.IGNORECASE,
)

YEAR_RE = re.compile(r"\b((?:19|20)\d{2})\b")
SEASON_EP_RE = re.compile(r"[Ss](\d{1,2})[Ee](\d{1,2})")
SEASON_ONLY_RE = re.compile(r"(?:[Ss]eason[\s._]?|[Ss])(\d{1,2})\b", re.IGNORECASE)


def split_camel(s: str) -> str:
    """vlsiTesting → vlsi Testing, then title_case handles the rest."""
    return re.sub(r"([a-z])([A-Z])", r"\1 \2", s)


def clean(raw: str, media_type: str) -> str:
    name = raw.strip()

    # Pre-clean site watermarks BEFORE camelCase split
    name = re.sub(r"(?i)^www\.\S+\s*[-–]?\s*", "", name)          # www.site.com -
    name = re.sub(r"(?i)^\S+\.(com|net|org|is|re|to)\s*[-–]\s*", "", name)  # site.com -
    name = re.sub(r"(?i)\s*[-–]\s*\S+\.(com|net|org|is|re|to)\s*$", "", name)  # - site.com

    # Split camelCase (useful for Upskill folder names like vlsiTesting)
    name = split_camel(name)

    # Drop file extension
    name = re.sub(r"\.[a-zA-Z0-9]{2,5}$", "", name)

    # Extract year before we mangle the string
    year_m = YEAR_RE.search(name)
    year = year_m.group(1) if year_m else None

    # Cut at first scene tag
    cut = SCENE_CUTOFF.search(name)
    if cut:
        name = name[: cut.start()]

    # Remove year token (re-added cleanly later)
    if year:
        name = re.sub(r"\b" + re.escape(year) + r"\b", "", name)

    # Remove season/episode tokens for folder-level naming
    name = SEASON_EP_RE.sub("", name)
    name = SEASON_ONLY_RE.sub("", name)

    # Remove all remaining bracket groups
    name = re.sub(r"\[.*?\]", "", name)
    name = re.sub(r"\(.*?\)", "", name)
    name = re.sub(r"\{.*?\}", "", name)

    # Strip orphaned tokens that survive after bracket removal
    name = re.sub(r"\bEPs?\b", "", name, flags=re.IGNORECASE)
    name = re.sub(r"\bPart\s*$", "", name, flags=re.IGNORECASE)

    # Remove leftover trailing dash/dot
    name = re.sub(r"(?i)\s*[-–]\s*$", "", name)

    # Normalise separators → spaces
    name = re.sub(r"[._\-]+", " ", name)
    name = re.sub(r"\s+", " ", name).strip()

    # Apply Title Case
    name = title_case(name)

    if media_type == "movie":
        if year:
            return f"{name} ({year})"
        return name

    elif media_type == "show":
        return name  # No year in show folder name

    else:  # upskill / generic
        return name


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: _rename_helper.py <movie|show|upskill> <raw_name>", file=sys.stderr)
        sys.exit(1)
    media_type = sys.argv[1].lower()
    raw_name = " ".join(sys.argv[2:])
    print(clean(raw_name, media_type))
