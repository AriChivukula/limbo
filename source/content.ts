import "@babel/polyfill";

export function shouldRefreshPage(url: string): boolean {
  return url.match(/^https:\/\/([a-z0-9]+[.])*westlaw.com\/.*$/) !== null;
}

export function refreshPageIfNeeded(): void {
  if (shouldRefreshPage(window.location.href)) {
    window.location.reload();
  }
}

console.log("Setting westlaw refresh timeout");
setTimeout(
  refreshPageIfNeeded,
  60 * 1000,
);
