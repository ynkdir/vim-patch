i=1
while test -f "test${i}_old.txt"; do
  diff --normal "test${i}_old.txt" "test${i}_new.txt" > "test${i}.normal"
  diff -c "test${i}_old.txt" "test${i}_new.txt" > "test${i}.context"
  diff -u "test${i}_old.txt" "test${i}_new.txt" > "test${i}.unified"
  i=$((i + 1))
done

