for file in input/*.egg
do
  mv "$file" "${file/.egg/.fdl}"
done
