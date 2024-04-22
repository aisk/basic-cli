app "stdin"
    packages { pf: "../platform/main.roc" }
    imports [
        pf.Stdout,
        pf.Stderr,
        pf.Stdin,
        pf.Task.{ Task },
    ]
    provides [main] to pf

main : Task {} I32
main =
    Stdout.line! "Enter a series of number characters (0-9):"
    numberBytes = takeNumberBytes!

    if List.isEmpty numberBytes then
        Stderr.line "Expected a series of number characters (0-9)"
    else
        when Str.fromUtf8 numberBytes is
            Ok nStr ->
                Stdout.line "Got number $(nStr)"

            Err _ ->
                Stderr.line "Error, bad utf8"

takeNumberBytes : Task (List U8) _
takeNumberBytes =

    bytesRead = Stdin.bytes!

    numberBytes =
        List.walk bytesRead [] \bytes, b ->
            if b >= '0' && b <= '9' then
                List.append bytes b
            else
                bytes

    Task.ok numberBytes
