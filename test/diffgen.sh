i=1
while test -f "test${i}_old.txt"; do
  diff --normal "test${i}_old.txt" "test${i}_new.txt" > "test${i}.normal"
  diff -c "test${i}_old.txt" "test${i}_new.txt" > "test${i}.context"
  diff -u "test${i}_old.txt" "test${i}_new.txt" > "test${i}.unified"
  i=$((i + 1))
done

diff -c0 test11_old.txt test11_new.txt > test11.context
diff -u0 test11_old.txt test11_new.txt > test11.unified
diff -c0 test12_old.txt test12_new.txt > test12.context
diff -u0 test12_old.txt test12_new.txt > test12.unified
diff -c0 test13_old.txt test13_new.txt > test13.context
diff -u0 test13_old.txt test13_new.txt > test13.unified
