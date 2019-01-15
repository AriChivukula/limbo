import "@babel/polyfill";

export function shouldRefreshPage(url: string): boolean {
  return url.match(/^https:\/\/([a-z0-9]+[.])*westlaw.com\/.*$/) !== null;
}

export function refreshPageIfNeeded(): void {
  console.log("Starting Refresh Clock");
  if (!window) {
    console.log("Test Exit");
    return;
  }
  if (!shouldRefreshPage(window.location.href)) {
    console.log("Wrong Page");
    return;
  }
  setTimeout(
    window.location.reload,
    60 * 1000,
  );
}

refreshPageIfNeeded();
