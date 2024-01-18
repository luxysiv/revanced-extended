import logging
from src import session
from bs4 import BeautifulSoup

def get_download_page(version: str) -> str:
    version = version.replace(".", "-")

    apkmirror_url = "https://www.apkmirror.com"
    apkmirror_yt_url = (
        f"https://www.apkmirror.com/apk/google-inc/youtube/youtube"
        + f"-{version.replace('.', '-')}-release/"
    )

    response = session.get(apkmirror_yt_url)
    response.raise_for_status()

    soup = BeautifulSoup(response.content, "lxml")
    yt_links = soup.find_all("div", attrs={"class": "table-row headerFont"})
    yt_apk_page = apkmirror_url

    for link in yt_links[1:]:
        if link.find_all("span", attrs={"class": "apkm-badge"})[0].text == "APK":
            yt_apk_page += link.find_all("a", attrs={"class": "accent_color"})[0]["href"]
            break

    return yt_apk_page

def extract_download_link(page: str) -> str:
    apkmirror_url = "https://www.apkmirror.com"

    res = session.get(page)
    res.raise_for_status()

    soup = BeautifulSoup(res.content, "lxml")
    apk_dl_page = soup.find_all("a", attrs={"class": "accent_bg"})
    apk_dl_page_url = apkmirror_url + apk_dl_page[0]["href"]

    res = session.get(apk_dl_page_url)
    res.raise_for_status()

    soup = BeautifulSoup(res.content, "lxml")
    apk_page_details = soup.find_all("a", attrs={"rel": "nofollow"})
    apk_link = apkmirror_url + apk_page_details[0]["href"]

    return apk_link
