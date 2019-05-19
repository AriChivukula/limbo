import "@babel/polyfill";
import {
  sitation,
} from "sitation";

export function findAndPrintCitations(): void {
  console.log("Looking for Citations");
  console.log(sitation(""));
}

findAndPrintCitations();
