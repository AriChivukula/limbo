import "@babel/polyfill";

export function shouldRefreshPage(url: string): boolean {
  return url.match(/^https:\/\/([a-z0-9]+[.])*westlaw.com\/.*$/) !== null;
}

export function refreshPageIfNeeded(): void {
  if (shouldRefreshPage(window.location.href)) {
    setTimeout(
      window.location.reload,
      60 * 1000,
    );
  }
}

console.log("Setting westlaw refresh timeout");
refreshPageIfNeeded();
