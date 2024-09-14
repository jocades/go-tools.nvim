package go_test

import (
	"fmt"
	"testing"
)

func TestStuff(t *testing.T) {
	fmt.Println("testing...")
}

func TestOtherStuff(t *testing.T) {
	t.Error("got x, want y")
}

/* === RUN   TestStuff
testing...
--- PASS: TestStuff (0.00s)
=== RUN   TestOtherStuff
    main_test.go:13: TODO
--- FAIL: TestOtherStuff (0.00s)
FAIL
FAIL	command-line-arguments	0.004s
FAIL
*/

/*{
  Action = "run",
  Package = "command-line-arguments",
  Test = "TestOtherStuff",
  Time =

{
  Action = "fail",
  Elapsed = 0.004,
  Package = "command-line-arguments",
  Time = "2024-09-14T07:56:58.775583+02:00"
}
*/
