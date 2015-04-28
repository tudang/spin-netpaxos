## Run verification with spin

```
$spin -a netpaxos.pml
$gcc -o pan pan.c
$./pan
```

## Run verification with ispin
```
$ispin netpaxos.pml
```
1. Select verification tab
2. In Safety, only select **+assertion violations**
3. in Never Claims, select **use claim**
4. Press **Run** button