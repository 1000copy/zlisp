# ZLisp 0.1

哇哦，ZLisp是一个大约300行的一个LISP解释器，使用Zig语言编写出来。

## 为什么选择实现LISP？

这是因为LISP语言拥有极度简洁的语法的同时，还可以有非常灵活和强大的表达能力。

## 为什么选择用Zig实现？

我曾经用C语言实现过一个LISP解释器，现在我想要学习Zig语言，并且想要借机对比两门语言的特点，是否果然Zig语言比C更好。
我的结论是，Zig是更好的C。

## 目前实现到什么程度？

解析LISP语言的基本语法
实现4个LISP原语，包括加减乘除

## 未来还要做什么功能？

支持更多语法，包括字符串，标注，标引
支持更多LISP原语，包括append,begin,car,cdr,cons,=,length,list,not,print,define,setq,repeat,load,eval

## 如何参与对项目做贡献？

1. Sign into GitHub 
2. Fork the project repository 
3. Clone your fork 
4. Navigate to your local repository and code
5. make your Pull Request
## ZLisp Zen

我信奉的是，绝对直截了当的实现意图，没有任何技巧

## ref

Peter norvig 's lisp written by python https://www.norvig.com/lispy.html