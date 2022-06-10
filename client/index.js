import { Elm } from "./src/Main.elm";

let apiUrl = "http://localhost:8000";
if (process.env.NODE_ENV === "production") {
  apiUrl = "https://gg2-assembler-test.vib.be/api/v1";
}

const app = Elm.Main.init({
  node: document.getElementById("elm"),
  flags: {
    ...JSON.parse(localStorage.getItem("model")),
    ...{ apiUrl: process.env.GGW_API_URL || apiUrl },
  },
});

app.ports.save.subscribe((model) => {
  localStorage.setItem("model", JSON.stringify(model));
});
