#!/usr/bin/env python3
import os
import sys
import io
import time
import base64
import atexit
import weakref
from selenium import webdriver
from selenium.webdriver.remote import webdriver as RemoteWebDriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.keys import Keys
from PIL import Image


DEFAULT_SCREENSHOT_TARGET = "screenshot.png"


class MySelenium(RemoteWebDriver.WebDriver):
    def __init__(self, *args, **kwargs):
        self._finalizer = weakref.finalize(self, self.quit)
        super().__init__(*args, **kwargs)

    def screenshot_all(self, filename=DEFAULT_SCREENSHOT_TARGET):
        total_width = browser.execute_script("return document.documentElement.scrollWidth")
        total_height = browser.execute_script("return document.documentElement.scrollHeight")
        window_height = browser.execute_script("return document.documentElement.clientHeight")

        browser.set_window_size(width=total_width + (total_width - browser.execute_script("return document.documentElement.clientWidth")), height=browser.get_window_size()['height'])

        result = Image.new('RGB', (total_width, total_height))

        times = int(total_height / window_height)
        for i in range(times):
            browser.execute_script("window.scrollTo(0, {});".format(window_height * i))
            time.sleep(0.2)
            base64_image = browser.get_screenshot_as_base64()
            base64_image_io = io.BytesIO(base64.b64decode(base64_image))
            image = Image.open(base64_image_io)
            result.paste(image, (0, window_height * i))
            image.close()

        # Last One
        last_height = total_height % window_height
        if last_height > 0:
            browser.execute_script("window.scrollTo(0, {});".format(total_height))
            time.sleep(0.2)
            base64_image = browser.get_screenshot_as_base64()
            base64_image_io = io.BytesIO(base64.b64decode(base64_image))
            image = Image.open(base64_image_io)
            crop_image = image.crop((0, image.size[1] - last_height, image.size[0], image.size[1]))
            result.paste(crop_image, (0, total_height - last_height))
            image.close()

        with open(filename, 'wb') as target_file:
            result.save(target_file)

RemoteWebDriver.WebDriver = MySelenium


class Chromedriver(webdriver.Chrome):
    def __init__(self, *args, chrome_options=None, **kwargs):
        if chrome_options is None:
            chrome_options = Options()
        chrome_options.add_argument('--no-sandbox')
        chrome_options.add_argument('--ignore-certificate-errors')
        chrome_options.add_argument('--start-maximized')
        chrome_options.add_argument('--disable-infobars')
        super().__init__(*args, chrome_options=chrome_options, **kwargs)
        atexit.register(self.quit)

    def screenshot_all(self, filename=DEFAULT_SCREENSHOT_TARGET):
        MySelenium.screenshot_all(self, filename)

def open_webs(*sites):
    browser = Chromedriver()
    print(sites)

    handle = browser.window_handles[0]

    if len(sites) >= 1:
        link = sites[0]
        browser.get(link)

    for link in sites[1:]:
        browser.execute_script("window.open('{url}');".format(url=link))
        # browser.find_element_by_tag_name('body').send_keys(Keys.CONTROL + 't')

    browser.switch_to_window(handle)

    print('>>>> User variable "browser" to control the browser. <<<<')


if __name__ == "__main__":
    if len(sys.argv) > 1:
        sites = sys.argv[1:]
    else:
        sites = []

    open_webs(*sites)
