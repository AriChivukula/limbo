import "@babel/polyfill";

import {
  shouldRefreshPage
} from "./content";

chrome.tabs.onUpdated.addListener(function(tabId, changeInfo, tab) {
  if (shouldRefreshPage(tab.url)) {
    chrome.pageAction.show(tabId);
  } else {
    chrome.pageAction.hide(tabId);
  }
});
