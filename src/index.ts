import pool from "./db";
import express from "express";


const app = express();
const port = 50000;


app.get("/test/database", async (_, res) => {
  try {
    await pool.query("CREATE TABLE test ();");
    await pool.query("DROP TABLE test;");

    res.status(200).send("Test success!")
  }
  catch (err) {
    console.error(err);

    res.status(500).send("Database is disconnected");
  }
});


app.listen(port, () => console.log(
  `Server is listening on ${port}`));
