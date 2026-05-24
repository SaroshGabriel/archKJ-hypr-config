#!/usr/bin/env python3
"""
auto-sort.py — Non-interactive bulk classifier for qBittorrent downloads on REDACTED.
Moves every known unsorted item into Movies/Indian, Movies/Foreign,
Shows/Indian, Shows/Foreign, or Upskill with a clean Title-Case name.

Usage:
  python3 auto-sort.py [--dry-run]

TORRENTS_DIR env var overrides the default download path.
"""

import os
import sys
import shutil
import subprocess
import glob

TORRENTS = os.environ.get("TORRENTS_DIR", "/mnt/portableUSB256GB")
HELPER   = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_rename_helper.py")
DRY_RUN  = "--dry-run" in sys.argv

CATEGORY_DIRS = {
    "movies-indian":  os.path.join(TORRENTS, "Movies", "Indian"),
    "movies-foreign": os.path.join(TORRENTS, "Movies", "Foreign"),
    "shows-indian":   os.path.join(TORRENTS, "Shows",  "Indian"),
    "shows-foreign":  os.path.join(TORRENTS, "Shows",  "Foreign"),
    "upskill":        os.path.join(TORRENTS, "Upskill"),
}

# ── Classification manifest ─────────────────────────────────────────────────
# Key: exact name as seen in TORRENTS root (file or directory)
# Value: ("category", "kind")
MANIFEST = {
    # ── Movies / Indian ──────────────────────────────────────────────────
    "12.Guide.1965.x264-worldmkv.mkv":                                  ("movies-indian", "movie"),
    "Article 15 (2019) Hindi 720p HDRip x264 AAC 5.1 ESubs -JM Team":   ("movies-indian", "movie"),
    "Assi (2026) 720p 10bit DS4K ZEE5 WEBRip x265 HEVC Hindi DDP 5.1 ESub - Immortal.mkv": ("movies-indian", "movie"),
    "Bhagwat Chapter One Raakshs (2025) Hindi 1080p WEBRip x264 DD 5.1 ESub.mkv": ("movies-indian", "movie"),
    "Bheja.Fry.2007.DVDRip.Xvid.Subs.TmG":                             ("movies-indian", "movie"),
    "Chup Chup Ke 2006 Hindi HDRip 720p x264 AC3...Hon3y":              ("movies-indian", "movie"),
    "Gangs of Wasseypur 2012 Part 1 Hindi 1080p Blu-Ray x264 DD 5.1 ESubs-Masti": ("movies-indian", "movie"),
    "Gangs of Wasseypur 2012 Part 2 Hindi 1080p Blu-Ray x264 DD 5.1 ESubs-Masti": ("movies-indian", "movie"),
    "Hera Pheri 2000 Hindi 720p HDrip x264...Hon3y":                    ("movies-indian", "movie"),
    "Jai Bhim (2021) Hindi 720p WEBRip x264 AAC Esub.mkv":             ("movies-indian", "movie"),
    "Mughal-E-Azam.1960.1080p.WEB-DL.AVC.AAC.ESub.DDR.mp4":           ("movies-indian", "movie"),
    "My name is Khan 2010 Bluray 720p H264 AAC Eng-sub":                ("movies-indian", "movie"),
    "Rashmi Rocket (2021) Hindi UNTOUCHED 720p Zee5 WEB-DL AAC2.0 x264 ESub 1GB [Themoviesboss].mkv": ("movies-indian", "movie"),
    "Saheb Biwi Aur Gangster 2011 Hindi 720p DvDRip x264...Hon3y":      ("movies-indian", "movie"),
    "Sholay (1975) [WEBRip] [1080p] [YTS.AM]":                         ("movies-indian", "movie"),
    "Welcome 2007 Hindi 720p DvDRip CharmeLeon Silver RG":              ("movies-indian", "movie"),
    "Whistle  2025 1080p WEB-DL HEVC x265 10Bit DDP5.1 Subs KINGDOM_RG": ("movies-indian", "movie"),
    "www.2MovieRulz.com - Babumoshai Bandookbaaz (2017) 720p Hindi - WEB-HD - AVC - AAC - 1.5GB.mkv": ("movies-indian", "movie"),

    # ── Movies / Foreign ─────────────────────────────────────────────────
    "5.Centimeters.Per.Second.2007.1080p.BluRay.x264-W4F[rarbg]":      ("movies-foreign", "movie"),
    "A Few Good Men (1992) (1080p BluRay x265 HEVC 10bit HDR AAC 7.1 afm72)": ("movies-foreign", "movie"),
    "Annihilation (2018) [BluRay] [1080p] [YTS.AM]":                   ("movies-foreign", "movie"),
    "Crime 101 2026 1080p WEB Line HEVC x265 BONE.mkv":                ("movies-foreign", "movie"),
    "Evil Dead Rise (2023) 1080p 10bit Bluray x265 HEVC [Org DD 5.1 Hindi + DD 5.1 English] MSubs ~ TombDoc.mkv": ("movies-foreign", "movie"),
    "First Man (2018) [WEBRip] [1080p] [YTS.AM]":                      ("movies-foreign", "movie"),
    "Immortal Combat 2026 1080p WEB-DL HEVC x265 5.1 BONE.mkv":       ("movies-foreign", "movie"),
    "I Want to Eat Your Pancreas 2018 720p BluRay x264 800MB-Tv21":    ("movies-foreign", "movie"),
    "Jaws (1975) [2160p] [4K] [BluRay] [5.1] [YTS.MX]":               ("movies-foreign", "movie"),
    "Pulp Fiction (1994) (1080p BluRay x265 HEVC 10bit AAC 5.1 Tigole)": ("movies-foreign", "movie"),
    "Saving Private Ryan (1998) [1080p]":                               ("movies-foreign", "movie"),
    "Spirited Away (2001) RM (1080p BluRay x265 HEVC 10bit EAC3 7.1 Japanese Garshasp)": ("movies-foreign", "movie"),
    "The Legend of Aang - The Last Airbender 2026 [INTERNAL] 1080p H.264 English AAC 2.0.mkv": ("movies-foreign", "movie"),
    "The.Lighthouse.2019.1080p.WEB-DL.H264.AC3-EVO[TGx]":             ("movies-foreign", "movie"),
    "www.UIndex.org    -    Ne Zha 2 A K A Nezha Mo Tong Nao Hai 2025 DUAL-AUDIO CHI-ENG 1080p 10bit WEBRip 6CH X265 HEVC-PSA": ("movies-foreign", "movie"),

    # ── Shows / Indian ───────────────────────────────────────────────────
    "Rocket Boys (2022) S01 EP(01-08)":                                 ("shows-indian", "show"),
    "Rocket Boys (2023) S02 EP(01-08)":                                 ("shows-indian", "show"),

    # ── Shows / Foreign ──────────────────────────────────────────────────
    "Bon Appetit Your Majesty (2025) S01 Dual Audio [Hindi ORG-Korean] NetFlix 720p-Vegamovies.is": ("shows-foreign", "show"),
    "Dark.SEASON.01.S01.COMPLETE.DUAL-AUDIO.GER-ENG.1080p.10bit.WEBRip.6CH.x265.HEVC-PSA": ("shows-foreign", "show"),
    "Devs.S01.1080p.WEBRip.x265[eztv.re]":                            ("shows-foreign", "show"),
    "Euphoria.US.S02.COMPLETE.720p.HMAX.WEBRip.x264-GalaxyTV[TGx]":   ("shows-foreign", "show"),
    "Genie,.Make.a.Wish.S01.720p.NF.WEB-DL.Multi.AAC5.1.H.264-themoviesboss": ("shows-foreign", "show"),
    "If.Wishes.Could.Kill.S01.720p.ITA-KOR-ENG.WEBRip.x265.AAC-V3SP4EV3R": ("shows-foreign", "show"),
    "Made in Abyss":                                                    ("shows-foreign", "show"),
    "Mr.Robot.Season.2.Complete.720p.WEB-DL.EN-SUB.x264-[MULVAcoded]": ("shows-foreign", "show"),
    "One Punch Man - Season 3":                                         ("shows-foreign", "show"),
    "ReZero kara Hajimeru Isekai Seikatsu":                            ("shows-foreign", "show"),
    "Silo (2023) Season 1 S01 (1080p ATVP WEB-DL x265 HEVC 10bit EAC3 Atmos 5.1 t3nzin)": ("shows-foreign", "show"),
    "The.Peripheral.S01.COMPLETE.720p.AMZN.WEBRip.x264-GalaxyTV[TGx]": ("shows-foreign", "show"),
    "The.Silent.Sea.S01.COMPLETE.1080p.ENG-HIN-KOREAN.NF.10bit.DDP.5.1.x265.[HashMiner]": ("shows-foreign", "show"),
    "Vinland Saga - Season 2 (2023)":                                   ("shows-foreign", "show"),
}

CUSTOM_NAMES = {
    "Spirited Away (2001) RM (1080p BluRay x265 HEVC 10bit EAC3 7.1 Japanese Garshasp)": "Spirited Away (2001)",
    "Euphoria.US.S02.COMPLETE.720p.HMAX.WEBRip.x264-GalaxyTV[TGx]":   "Euphoria",
    "www.UIndex.org    -    Ne Zha 2 A K A Nezha Mo Tong Nao Hai 2025 DUAL-AUDIO CHI-ENG 1080p 10bit WEBRip 6CH X265 HEVC-PSA": "Ne Zha 2 (2025)",
    "12.Guide.1965.x264-worldmkv.mkv":                                 "Guide (1965)",
    "ReZero kara Hajimeru Isekai Seikatsu":                            "Re Zero Kara Hajimeru Isekai Seikatsu",
    "Genie,.Make.a.Wish.S01.720p.NF.WEB-DL.Multi.AAC5.1.H.264-themoviesboss": "Genie Make A Wish",
    "The Legend of Aang - The Last Airbender 2026 [INTERNAL] 1080p H.264 English AAC 2.0.mkv": "The Last Airbender (2026)",
}

MULTI_SEASON_SHOWS = {
    "Rocket Boys": [
        ("Rocket Boys (2022) S01 EP(01-08)", "Season 01"),
        ("Rocket Boys (2023) S02 EP(01-08)", "Season 02"),
    ],
}


def clean_name(raw: str, kind: str) -> str:
    if raw in CUSTOM_NAMES:
        return CUSTOM_NAMES[raw]
    result = subprocess.run(["python3", HELPER, kind, raw], capture_output=True, text=True)
    name = result.stdout.strip()
    return name if name else raw


def find_main_video(folder: str) -> "str | None":
    candidates = []
    for ext in ("*.mkv", "*.mp4", "*.avi", "*.m4v", "*.mov"):
        candidates.extend(glob.glob(os.path.join(folder, "**", ext), recursive=True))
    return max(candidates, key=os.path.getsize) if candidates else None


def move_item(raw: str, category: str, kind: str) -> None:
    src = os.path.join(TORRENTS, raw)
    dest_dir = CATEGORY_DIRS[category]
    is_file = os.path.isfile(src)
    name = clean_name(raw, "movie" if kind == "movie" else kind)

    if kind in ("movie", "upskill"):
        dest_folder = os.path.join(dest_dir, name)
        if is_file:
            ext = os.path.splitext(raw)[1]
            print(f"  FILE → {dest_folder}/")
            if not DRY_RUN:
                os.makedirs(dest_folder, exist_ok=True)
                shutil.move(src, os.path.join(dest_folder, name + ext))
        else:
            dest_path = os.path.join(dest_dir, name)
            print(f"  DIR  → {dest_path}/")
            if not DRY_RUN:
                os.makedirs(dest_dir, exist_ok=True)
                shutil.move(src, dest_path)
                video = find_main_video(dest_path)
                if video:
                    video_ext = os.path.splitext(video)[1]
                    new_video = os.path.join(dest_path, name + video_ext)
                    old_video = os.path.join(dest_path, os.path.relpath(video, src))
                    if os.path.exists(old_video) and old_video != new_video:
                        try:
                            os.rename(old_video, new_video)
                        except Exception:
                            pass
    else:
        dest_path = os.path.join(dest_dir, name)
        print(f"  DIR  → {dest_path}/")
        if not DRY_RUN:
            os.makedirs(dest_dir, exist_ok=True)
            shutil.move(src, dest_path)


def handle_multi_season_shows() -> int:
    ok = 0
    for show_name, seasons in MULTI_SEASON_SHOWS.items():
        first_raw = seasons[0][0]
        if first_raw not in MANIFEST:
            print(f"SKIP multi-season (not in MANIFEST): {first_raw}")
            continue
        category, _ = MANIFEST[first_raw]
        parent = os.path.join(CATEGORY_DIRS[category], show_name)
        print(f"[{category}] {show_name}/ (multi-season)")
        for raw, season_label in seasons:
            src = os.path.join(TORRENTS, raw)
            if not os.path.exists(src):
                print(f"  SKIP (not found): {raw}")
                continue
            print(f"  {season_label}: {raw}")
            if not DRY_RUN:
                os.makedirs(parent, exist_ok=True)
                shutil.move(src, os.path.join(parent, season_label))
            ok += 1
    return ok


def main():
    if DRY_RUN:
        print(f"[DRY RUN — nothing will be moved]\nTORRENTS: {TORRENTS}\n")

    ok = skipped = errors = 0
    multi_season_raws = {raw for seasons in MULTI_SEASON_SHOWS.values() for raw, _ in seasons}

    for raw, (category, kind) in MANIFEST.items():
        if raw in multi_season_raws:
            continue
        if not os.path.exists(os.path.join(TORRENTS, raw)):
            skipped += 1
            continue
        print(f"[{category}] {raw}")
        try:
            move_item(raw, category, kind)
            ok += 1
        except Exception as e:
            print(f"  ERROR: {e}")
            errors += 1

    ok += handle_multi_season_shows()
    print(f"\nDone — moved: {ok}, skipped: {skipped}, errors: {errors}")
    if DRY_RUN:
        print("Re-run without --dry-run to apply changes.")


if __name__ == "__main__":
    main()
