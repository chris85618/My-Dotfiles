#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

# TODO: 使用argparse讀取所有資訊並讓設定可參數化，以便作到全自動化

import datetime
import time
from chrome_robot import Chromedriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support import expected_conditions as EC


class RedmineChromedriver(Chromedriver):
    def fetch_information(self):
        result_dict = {}
        try:
            default_subtitle = self.wait.until(EC.visibility_of_element_located(
                (By.XPATH, '//*[@id="fakeDynamicForm"]/div/div[2]/div[1]/div/div/h3'))).text
            subtitle = input(f"請輸入標題 (e.g. {default_subtitle}): ")
            if len(subtitle.strip()) == 0:
                subtitle = default_subtitle
        except BaseException:
            subtitle = input(f"請輸入標題: ")
        subtitle = subtitle.strip()
        result_dict['subtitle'] = subtitle

        try:
            default_priority = self.wait.until(EC.visibility_of_element_located(
                (By.XPATH, '//*[@id="fakeDynamicForm"]/div/div[3]/div[1]/div[1]/div[2]/div[2]'))).text
            priority = input(f"請輸入優先度 (e.g. {default_priority}): ")
            if len(priority.strip()) == 0:
                priority = default_priority
        except BaseException:
            priority = input(f"請輸入優先度: ")
        priority = priority.strip()
        result_dict['priority'] = priority

        return result_dict

    def generate_daily_issues(self, parent_issue_url, subtitle, priority, from_date, to_date, tracker, estimated_hours):
        self.get(parent_issue_url)
        time.sleep(0.3)
        self.wait.until(EC.element_to_be_clickable
                ((By.XPATH, '//*[@id="issue_tree"]/div/a'))).click()

        current_date=from_date

        while current_date < to_date:
            try:
                self.wait.until(EC.element_to_be_clickable((By.ID, 'issue_tracker_id')))
                time.sleep(0.3)

                # Issue tracker ID
                self.wait.until(EC.element_to_be_clickable((By.ID, 'issue_tracker_id'))).send_keys(tracker)
                time.sleep(0.2)

                # subject
                self.wait.until(EC.element_to_be_clickable((By.ID, 'issue_subject'))).send_keys(
                    f"{subtitle} - {current_date.strftime('%Y-%m-%d')}")
                time.sleep(0.2)

                # (TODO) Description
                # self.wait.until(EC.element_to_be_clickable((By.ID, 'issue_description'))).send_keys()
                # time.sleep(0.2)

                # priority
                self.wait.until(EC.element_to_be_clickable((By.ID, 'issue_priority_id'))).send_keys(priority)
                time.sleep(0.2)

                # assign
                self.wait.until(EC.element_to_be_clickable((By.XPATH, '//*[@id="attributes"]/div[1]/div[1]/p[3]/a'))).click()
                time.sleep(0.2)

                # start date
                start_date_element = self.wait.until(EC.element_to_be_clickable((By.ID, 'issue_start_date')))
                start_date_element.send_keys(f"{current_date.strftime('%Y')}")
                start_date_element.send_keys(Keys.ARROW_RIGHT)
                start_date_element.send_keys(f"{current_date.strftime('%m%d')}")
                time.sleep(0.2)

                # due date
                due_date_element = self.wait.until(EC.element_to_be_clickable((By.ID, 'issue_due_date')))
                due_date_element.send_keys(f"{current_date.strftime('%Y')}")
                due_date_element.send_keys(Keys.ARROW_RIGHT)
                due_date_element.send_keys(f"{current_date.strftime('%m%d')}")
                time.sleep(0.2)

                # estimated hours
                self.wait.until(EC.element_to_be_clickable((By.ID, 'issue_estimated_hours'))).send_keys(f"{estimated_hours}")
                time.sleep(0.2)

                # Next one
                self.wait.until(EC.element_to_be_clickable((By.XPATH, '//*[@id="issue-form"]/input[5]'))).click()

                current_date += datetime.timedelta(days=1)
            except KeyboardInterrupt:
                raise
            except:
                time.sleep(2)
                self.get(parent_issue_url)
                time.sleep(0.3)
                self.wait.until(EC.element_to_be_clickable((By.XPATH, '//*[@id="issue_tree"]/div/a'))).click()
                continue


if __name__ == "__main__":
    browser = RedmineChromedriver()
    browser.get('https://chris85618.diskstation.me:61443/')
    print("請登入Redmine")
else:
    browser = None


def generate_daily_issues(browser=browser):
    parent_issue_info = {}

    parent_issue_url = input("請輸入parent issue的URL: ").strip()
    parent_issue_info['parent_issue_url'] = parent_issue_url

    browser.get(parent_issue_url)
    time.sleep(2)
    parent_issue_info.update(browser.fetch_information())

    from_date_input = input(f"From date (e.g. {datetime.date.today()}): ")
    from_date = datetime.datetime.strptime(from_date_input.strip(), "%Y-%m-%d")
    parent_issue_info['from_date'] = from_date

    to_date_input = input(f"To date (e.g. {datetime.date.today()}): ")
    to_date = datetime.datetime.strptime(to_date_input.strip(), "%Y-%m-%d")
    to_date += datetime.timedelta(days=1)
    parent_issue_info['to_date'] = to_date

    assert from_date < to_date

    default_tracker = "Task"
    tracker = input(f"請輸入追蹤標籤(e.g. {default_tracker}): ")
    if len(tracker.strip()) == 0:
        tracker = default_tracker
    parent_issue_info['tracker'] = tracker

    estimated_hours = float(input(f"請輸入預估工時: ").strip())
    parent_issue_info['estimated_hours'] = estimated_hours

    browser.generate_daily_issues(**parent_issue_info)
