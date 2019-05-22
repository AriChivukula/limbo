import "@babel/polyfill";
import {
  sitation,
} from "sitation";

export function parseCitations(content: string): [string, string][] {
  const citationArray: [string, string][] = [];
  const citations = sitation(content);
  for (const citation of citations.split("\n")) {
    const parts = citation.split(",");
    if (parts.length < 7) {
      continue;
    }
    citationArray.push([parts[2] + " " + parts[3] + " " + parts[4], "https://www.courtlistener.com/c/" + parts[3] + "/" + parts[2] + "/" + parts[4] + "/"]);
  }
  return citationArray;
}

if (typeof document !== 'undefined') {
  // @ts-ignore
  const citations = parseCitations(document.body.innerText);
  console.log(citations);
  for (const citation of citations) {
    // @ts-ignore
    document.body.innerHTML = document.body.innerHTML.replace(new RegExp(citation[0], "ig"), "<a href=\"" + citation[1] + "\">" + citation[0] + "</a>");
  }
}
