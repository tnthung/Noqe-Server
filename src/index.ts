import express from "express";


const app = express();
const port = 50000;


app.get("/test", (_, res) => {
  res.status(200).send("Test success!")
});


app.listen(port, () => console.log(
  `Server is listening on ${port}`));
