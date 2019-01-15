import "@babel/polyfill";

export function shouldRefreshPage(url: string): boolean {
  return url.match(/^https:\/\/([a-z0-9]+[.])*westlaw.com\/.*$/) !== null;
}

setTimeout(
  () => {
    if (shouldRefreshPage(window.location.href)) {
      window.location.reload();
    }
  },
  60 * 60 * 1000,
);
