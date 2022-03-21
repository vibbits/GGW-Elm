import { Elm } from "./src/Main.elm";

const app = Elm.Main.init({
  node: document.getElementById("elm"),
  flags: JSON.parse(localStorage.getItem("model")),
});

app.ports.save.subscribe((model) => {
  localStorage.setItem("model", JSON.stringify(model));
});
