# cre
###### A common runtime environment (CRE) for distributed workflow languages.

[![hex.pm](https://img.shields.io/hexpm/v/cre.svg?style=flat-square)](https://hex.pm/packages/cre) [![Build Status](https://travis-ci.org/joergen7/cre.svg?branch=master)](https://travis-ci.org/joergen7/cre)

The common runtime environment (CRE) is a scalable execution environment for data analysis workloads running on top of [distributed Erlang](https://www.erlang.org). It is responsible for managing communication with a client, e.g., a language interpreter, and a number of application-specific worker processes. Herein, the common runtime environment performs scheduling, client and worker failure recovery, client back-pressure, and caching. The common runtime environment itself is application-independent. To specialize it towards a particular application, e.g., a workflow language, the `cre_client` and `cre_worker` behaviors must be implemented. The common runtime environment is based on the [gen_pnet](https://github.com/joergen7/gen_pnet) OTP behavior for modeling concurrent systems as Petri nets and is the featured execution environment for the [Cuneiform](https://cuneiform-lang.org) workflow language.


![cre Petri net model](priv/cre_master_pnet.png)

*Figure 1: Petri net model of the common runtime environment's master application. It provides interfaces to client applications (top and left) and worker processes (right).*

## Features

Here, we give an overview of the features, the CRE covers. The primary features of the CRE are scheduling, client back-pressure, fault tolerance, and caching.

### Scheduling

Scheduling is performed by associating a task with a given worker. Once the match has been made, the task is sent to the associated worker and the task-worker pair is ear-marked as busy. Since any task is allowed to be matched with any worker, the net structure effectively implements a random scheduler.

### Client Back-Pressure

Large workloads consisting of 1M tasks or more as well as a large number of clients can spam the master process to a degree where it stops working. The CRE protects itself from being overwhelmed by its clients by applying back-pressure to eager clients.

### Fault Tolerance

The CRE can serve an arbitrary number of clients and can feed an arbitrary number of workers. In large compute clusters this means that there is a realistic chance for one or more connected processes to fail. The CRE creates a link to each client and each worker and appropriately reacts to exit messages which are generated whenever a process stops running. I.e., demand sent to non-existing clients is recollected and tasks sent to non-existing workers are rescheduled. Also, the total amount of demand tokens in the net is kept proportional to the number of live workers.

### Caching

Often in large-scale data analysis applications, the storage needed to keep intermediate results is much cheaper than the compute resources needed to derive these intermediate results. Accordingly, the CRE memoizes all task-result combinations over the duration of the CRE master's run.

## Usage

### Adding the CRE to a Project

#### rebar3

To integrate the CRE into a rebar3 managed project change the `deps` entry in your application's `rebar.config` file to include the tuple `{cre, "0.1.0"}`.

```erlang
{deps, [{cre, "0.1.0"}]}.
```

#### mix

```elixir
{:cre, "~> 0.1.0"}
```

### Creating a CRE Client Module

The CRE client is a service that takes a program from a user (or from another service) and computes its result. For that purpose, the client extracts from the program small, independent computational units, which we call applications, and sends them to the CRE master for reduction. Also, the client awaits the return of application results. The client continues to generate applications until all application results in a program are known and no new applications can be generated. Then the result of the program is returned to the user. Additionally, the client sends an application to the CRE master only if the CRE master has expressed demand for new applications. This protects the CRE master from being overwhelmed by its clients.

![cre Petri net model](priv/cre_client_pnet.png)

*Figure 2: Petri net model of the common runtime environment's client application. It provides a user interface (top and bottom) and an interface to the master application.*

#### User Interface

Let's say we have created a CRE client implementation in the module `my_cre_client`. We can start a client process from the module and link it to a CRE master by using the `cre_client:start_link/3` function. 

    cre:start().
    {ok, Cre} = cre:pid().
    InitArg = [].
    {ok, Client} = cre_client:start_link( Cre, my_cre_client, InitArg ).

In principle, we can now start querying the client by using the `cre_client:eval/2` function. This function takes a CRE client pid and a term `T` and returns the resulting value.

    T = {'and', {'not', true}, {'not', false}}.
    cre_client( Cre, T ).

The term we use here is in the syntax of the zero-order logic we use in the [example section](#example-a-distributed-zero-order-logic). If the CRE is live, it produces the result `false`. Note that we didn't add any workers to the CRE master yet, so the client request will just block and wait forever, unless we also add workers to the CRE master. How workers are implemented and added to the CRE master is described in the [worker module section](#creating-a-cre-worker-module).

#### Callback Functions

The CRE client is implemented by providing three callback functions: `init/1`, `is_value/2`, and `step/2`. In the following, we discuss the behavior expected from these callbacks.

##### init/1

```erlang
-callback init( InitArg :: _ ) -> UsrInfo :: _.
```
The `init/1` function takes an initial argument, and generates from it the user info field, that is subsequently handed to the `is_value/2` and `step/2` functions. Herein, the initial argument is the same as the last argument handed to the `cre_client:start_link/3` or `cre_client:start_link/4` functions which are used to start up a client process.

##### is_value/2

```erlang
-callback is_value( P :: _, UsrInfo :: _ ) -> boolean().
```
The `is_value/2` function takes a program `P` and the user info field generated by the `init/1` function and determines whether the program is a value. If the program is a value, that means that the program has terminated and the result is returned to the user.

##### step/2

```erlang
-callback step( {Q :: [_], C :: [{_, _}], T :: _}, UsrInfo :: _ ) ->
            {ok, {Q1 :: [_], C1 :: [{_, _}], T1 :: _}} | norule.
```
The `step/2` function takes a program of the form `{Q, C, T}` and the user info field generated by the `init/1` function and either generates a new program returning a tuple of the form `{ok, {Q1, C1, T1}}` or detects that no further progress can be made at this point in which case it returns `norule`. Herein, the `step/2` function is supposed to only add to the queue `Q` or leave it unchanged and to only remove from the cache `C` or leave it unchanged.

### Creating a CRE Worker Module

TODO

![cre Petri net model](priv/cre_worker_pnet.png)

*Figure 3: Petri net model of the common runtime environment's worker application. It interfaces only to the master application.*

#### Callback Functions

## Example: A Distributed Zero-Order Logic

There are several reasons why distributing a zero-order logic this way is utter waste. However, the example is instructive because there is a habitual familiarity of programmers with logic and also because it is a healthy exercise to reflect on when *not* to distribute.


### Reduction Semantics

#### Syntax

Here, we show how a simple zero-order logic can be distributed using the CRE. We describe the semantics of this logic as a reduction semantics. Thus, first we introduce its static syntax. It consists of truth values, negation, conjunction, and disjunction. The resulting syntax for expressions *e* looks as follows:

![Syntax: expression first version](priv/logic_syntax_expr1.png)

#### Notion of Reduction

Before we introduce the notion of reduction for the above logic, we need to extend the syntax by defining the concept of a value *v*, i.e., an expression that can be the result of an evaluation and that can play the role of an operand in a redex:

![Syntax: value](priv/logic_syntax_value.png)

Now we are ready to define the notion of reduction in form of the binary relation n. There should be no surprises here.

![E-neg-true](priv/logic_e-neg-true.png)

![E-neg-false](priv/logic_e-neg-false.png)

![E-and-true](priv/logic_e-and-true.png)

![E-and-false](priv/logic_e-and-false.png)

![E-or-true](priv/logic_e-or-true.png)

![E-or-false](priv/logic_e-or-false.png)

#### Evaluation Context

Before we introduce the reduction relation for the distributed zero-order logic we need to define the syntax of evaluation contexts:

![Syntax: evaluation context](priv/logic_syntax_evaluation_context.png)

Note that defining the evaluation context this way does not result in a deterministic reduction relation as would be the desirable when defining a standard reduction relation. This non-determinism allows us to find redexes in many places in the control string. This is important when we define the reduction relation for the CRE, since we want to send as many redexes as possible to the distributed execution environment regardless of how fast the CRE can generate replies.

#### Reduction Relation: A First Try

To get a reduction relation from the previously defined notion of reduction n, we create the compatible closure of n by applying it in the evaluation context *E*:

![E-red](priv/logic_e-red.png)

`[E-red]`

#### Reduction Relation: The CRE Way

The reduction relation defined in `[E-red]` sufficiently describes how evaluation in our zero-order logic is accomplished. However, it applies the notion of reduction in-place, thereby reducing one redex at a time in a sequential manner. Now the sport is to send the redex to a remote service instead of just reducing it, and to do so with as many redexes as we can find in an expression.

Accordingly, the first thing to do is to extend the syntax of expressions *e* with the concept of a future. Futures provide a way to mark redexes that have already been sent away to be computed.

![Syntax: expression second version](priv/logic_syntax_expr2.png)

Next, it is not enough to housekeep bare expressions. We need a way to represent redexes awaiting reduction and also redex-value pairs that we get back in return from the remote reduction service.

Accordingly, CRE programs are triples consisting of a queue, a cache, and a control string. This convention is reflected in the way we construct the syntax for programs *p*. In this example, the queue is a list of redexes awaiting reduction, the cache is a list of redex-value pairs holding the redex and the value associated with it according to the notion of reduction, and the control string is an expression under evaluation.

![Syntax: program](priv/logic_syntax_program.png)

Now that we have defined the evaluation context, we can express what the notion of reduction n means in the context of a program *p*. The updated reduction relation consists of two rules. The first rule defines how redexes are sent to the execution environment. This is achieved by enclosing a redex in a future and by enqueueing the redex.

![E-send](priv/logic_e-send.png)

`[E-send]`

Next we need to define how results which have been received via the cache are substituted into the control string:

![E-recv](priv/logic_e-recv.png)

`[E-recv]`

The notion of reduction n does not appear directly in the reduction relation anymore (we use it only in a side condition to identify redexes in `E-send`). This reflects the fact that the notion of reduction is applied by the worker and, thus, never explicitly appears in the way reduction is performed in the client.

In real applications, we let the client perform some reductions and defer only the "number crunching" to the CRE. In this example, however, we have the CRE do *all* reductions.

### A CRE Application from the Reduction Semantics

#### Syntax

```erlang
-type e() :: boolean()
           | {'not', e()}
           | {'and', e(), e()}
           | {'or', e(), e()}
           | {fut, e()}.
```

#### Notion of Reduction

```erlang
is_value( T, _UsrInfo ) -> is_boolean( T ).
```


```erlang
run( {'not', X}, _UsrInfo )      -> {ok, not X};
run( {'and', X1, X2}, _UsrInfo ) -> {ok, X1 andalso X2};
run( {'or', X1, X2}, _UsrInfo )  -> {ok, X1 orelse X2}.
```

#### Evaluation Context

```erlang
-type ctx() :: hole
             | {'not', ctx()}
             | {'and', ctx(), e()}
             | {'and', e(), ctx()}
             | {'or', ctx(), e()}
             | {'or', e(), ctx()}.
```

#### Reduction Relation

The `step/2` function has two cases which correspond to the two reduction rules `E-send` and `E-recv`.

```erlang
step( {Q, [], T}, _UsrInfo ) ->
  case find_context( T ) of
    {ok, {E, Redex}}   -> {ok, {[Redex|Q], [], in_hole( E, {fut, Redex} )}};
    {error, nocontext} -> norule
  end;
```

```erlang
step( {Q, [{Redex, Value}|C1], T}, _UsrInfo ) ->
  {ok, {Q, C1, subst_fut( T, Redex, Value )}}.
```

The `step/2` function is defined in terms of three other functions: `find_context/1` which takes an arbitrary expression and tries to decompose it into an evaluation context and a redex, `in_hole/2` which replaces the hole in an evaluation context with some expression (or another evaluation context), and `subst_fut/3` which replaces a future with its corresponding value.

Note that we had to define a reduction function even if the reduction rules given in the previous section were given in the form of a relation. We achieve the function property by constraining the `E-send` rule to situations where the cache is empty and by making the `find_context/1` function return the leftmost outermost redex, instead of just any redex.

Even though the reduction rules are now encoded in a function, evaluation is not deterministic in the order of reduction. The reason is that reduction results from the CRE can be received in any order regardless of the fact that the client has sent the redexes away in a deterministic order.

## Related Projects

- [Hadoop YARN](https://hadoop.apache.org/docs/current/hadoop-yarn/hadoop-yarn-site/YARN.html) is a large-scale data analysis platform that performs resource- and application management. YARN's resource manager is comparable with the CRE since it manages data analysis workloads by performing scheduling and failure recovery for a number of containers.
- [HTCondor](https://research.cs.wisc.edu/htcondor/) is a high-throughput data analysis platform. It is the underlying execution environment for [Pegasus](https://pegasus.isi.edu) whose workflow specification language is Pegasus DAX.
- [Toil](https://github.com/BD2KGenomics/toil) is a scalable pipeline management system. It is an execution environment running workflows specified in [Common Workflow Language (CWL)](https://github.com/common-workflow-language/common-workflow-language).
- [GenStage](https://github.com/elixir-lang/gen_stage) manages communication in producer-consumer networks. Thus, similar to the CRE, it is an application-independent scaffold which can be specialized to data analysis workloads.

## System Requirements

- [Erlang](https://www.erlang.org) OTP 18.0 or higher
- [Rebar3](https://www.rebar3.org) 3.0.0 or higher

## Resources

- [joergen7/gen_pnet](https://github.com/joergen7/gen_pnet). A generic Petri net OTP behavior, the CRE is based on.
- [joergen7/cuneiform](https://github.com/joergen7/cuneiform). A functional workflow language which can be executed with a Cuneiform-specific CRE.

## Authors

- Jörgen Brandt ([@joergen7](https://github.com/joergen7/)) [joergen.brandt@onlinehome.de](mailto:joergen.brandt@onlinehome.de)

## License

[Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0.html)