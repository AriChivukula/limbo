import "@babel/polyfill";
import {
  sitation,
} from "sitation";

export function parseCitations(content: string): string[] {
  const citationArray: string[] = [];
  const citations = sitation(content);
  for (const citation of citations.split("\n")) {
    const parts = citation.split(",");
    if (parts.length < 7) {
      continue;
    }
    citationArray.push("https://www.courtlistener.com/c/" + parts[3] + "/" + parts[2] + "/" + parts[4] + "/");
  }
  return citationArray;
}

if (typeof document !== 'undefined') {
  // @ts-ignore
  console.log(parseCitations(document.body.innerText));
}
