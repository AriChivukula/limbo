import "@babel/polyfill";

export function shouldRefreshPage(url: string): boolean {
  return url.match(/^https:\/\/([a-z0-9]+[.])*westlaw.com\/.*$/) !== null;
}
