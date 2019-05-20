import "@babel/polyfill";
import {
  sitation,
} from "sitation";

export function findCitations(): string {
  return parseCitations(document.body.innerText);
}

export function parseCitations(content: string): string {
  return sitation(content);
}

console.log(findCitations());
