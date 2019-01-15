import "@babel/polyfill";

import {
  shouldRefreshPage
} from "./content";

chrome.tabs.onUpdated.addListener((tabId: number, changeInfo: chrome.tabs.TabChangeInfo, tab: chrome.tabs.Tab) => {
  if (shouldRefreshPage(tab.url || "")) {
    chrome.pageAction.show(tabId);
  } else {
    chrome.pageAction.hide(tabId);
  }
});
