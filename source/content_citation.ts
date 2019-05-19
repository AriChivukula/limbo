import "@babel/polyfill";
import {
  sitation,
} from "sitation";

export function findAndPrintCitations(): string {
  return sitation("");
}

console.log(findAndPrintCitations());
