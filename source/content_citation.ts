import "@babel/polyfill";
import {
  sitation,
} from "sitation";

export function parseCitations(content: string): string {
  return sitation(content);
}

if (typeof document !== 'undefined') {
  // @ts-ignore
  console.log(parseCitations(document.body.innerText));
}
