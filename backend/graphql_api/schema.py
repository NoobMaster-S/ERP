import strawberry
from graphql_api.queries.main_queries import Query
from graphql_api.mutations.main_mutations import Mutation

schema = strawberry.Schema(query=Query, mutation=Mutation)
