# easy-lua-script
对 gevent 的模仿

***
这是纯 Lua 脚本,需要配合另一个工程 https://github.com/iAmYeWeiLong/easy-lua-cpp 才能 run

***

苦恼于 python 计算性能差,但是又喜欢 gevent 的编程模型. 因此产生了这个项目.

## 做了什么工作 ?
* gevent 所用到的 greenlet 是对称式协程,Lua 是非对称式协程,把 Lua 非对称协程转化成对称式协程
* 解决 Lua 脚本调用跨越 C 边界的问题
* Lua 和 Python 语言差异的问题,比如 异常处理部分等等

