app "record-builder"
    packages {
        pf: "../platform/main.roc",
    }
    imports [
        pf.Stdout,
        pf.Task.{ Task },
    ]
    provides [main] to pf

main : Task {} I32
main =
    myrecord : Task { apples : List Str, oranges : List Str } I32
    myrecord = Task.ok {
        apples: <- getFruit Apples |> Task.batch,
        oranges: <- getFruit Oranges |> Task.batch,
    }

    { apples, oranges } = myrecord!

    "Apples: "
    |> Str.concat (Str.joinWith apples ", ")
    |> Str.concat "\n"
    |> Str.concat "Oranges: "
    |> Str.concat (Str.joinWith oranges ", ")
    |> Stdout.line

getFruit : [Apples, Oranges] -> Task (List Str) *
getFruit = \request ->
    when request is
        Apples -> Task.ok ["Granny Smith", "Pink Lady", "Golden Delicious"]
        Oranges -> Task.ok ["Navel", "Blood Orange", "Clementine"]
