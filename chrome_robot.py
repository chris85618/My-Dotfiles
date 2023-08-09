#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

import os
import sys
import io
import time
import base64
import atexit
import weakref
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.remote import webdriver as RemoteWebDriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from PIL import Image


DEFAULT_SCREENSHOT_TARGET = "screenshot.png"


class MySelenium(RemoteWebDriver.WebDriver):
    def __init__(self, *args, **kwargs):
        self._finalizer = weakref.finalize(self, self.quit)
        super().__init__(*args, **kwargs)
        self.wait = WebDriverWait(self, 20)

    def shadow_root(self, element):
        return self.execute_script('return arguments[0].shadowRoot', element)

    def screenshot_all(self, filename=DEFAULT_SCREENSHOT_TARGET):
        total_width = self.execute_script(
            "return document.documentElement.scrollWidth")
        total_height = self.execute_script(
            "return document.documentElement.scrollHeight")

        self.set_window_size(
            width=(total_width +
                   (self.execute_script("return window.outerWidth")) -
                   (self.execute_script("return window.innerWidth"))),
            height=self.get_window_size()['height'])

        time.sleep(0.3)
        window_height = self.execute_script(
            "return window.innerHeight")

        result = Image.new('RGB', (total_width, total_height))

        times = int(total_height / window_height)
        for i in range(times):
            self.execute_script(
                "window.scrollTo(0, {});".format(window_height * i))
            time.sleep(0.2)
            base64_image = self.get_screenshot_as_base64()
            base64_image_io = io.BytesIO(base64.b64decode(base64_image))
            image = Image.open(base64_image_io)
            result.paste(image, (0, window_height * i))
            image.close()

        # Last One
        last_height = total_height % window_height
        if last_height > 0:
            self.execute_script("window.scrollTo(0, {});".format(total_height))
            time.sleep(0.2)
            base64_image = self.get_screenshot_as_base64()
            base64_image_io = io.BytesIO(base64.b64decode(base64_image))
            image = Image.open(base64_image_io)
            crop_image = image.crop(
                (0, image.size[1] - last_height, image.size[0], image.size[1]))
            result.paste(crop_image, (0, total_height - last_height))
            image.close()

        with open(filename, 'wb') as target_file:
            result.save(target_file)


RemoteWebDriver.WebDriver = MySelenium


class Chromedriver(webdriver.Chrome):
    def __init__(self, *args, options=Options(), **kwargs):
        options.add_argument('--no-sandbox')
        options.add_argument('--ignore-certificate-errors')
        options.add_argument('--start-maximized')
        options.add_argument('--disable-infobars')
        super().__init__(*args, options=options, **kwargs)
        atexit.register(self.quit)
        self.wait = WebDriverWait(self, 20)

    def shadow_root(self, element):
        return MySelenium.shadow_root(self, element)

    def screenshot_all(self, filename=DEFAULT_SCREENSHOT_TARGET):
        return MySelenium.screenshot_all(self, filename)


def open_webs(*sites):
    browser = Chromedriver()

    handle = browser.window_handles[0]

    is_first_tab = True

    for link in sites:
        try:
            if is_first_tab:
                browser.get(link)
                is_first_tab = False
            else:
                browser.execute_script("window.open('{url}');".format(url=link))
        except KeyboardInterrupt:
            raise
        except Exception:
            continue
        print(f'Open "{link}"')
        # browser.find_element_by_tag_name('body').send_keys(Keys.CONTROL + 't')

    browser.switch_to.window(handle)

    print('>>>> User variable "browser" to control the browser. <<<<')
    return browser


if __name__ == "__main__":
    if len(sys.argv) > 1:
        my_sites = sys.argv[1:]
    else:
        my_sites = []

    browser = open_webs(*my_sites)
