module Assistant
  class SqlValidator
    class Unsafe < StandardError; end

    # SQL keyword forms (EXTRACT, TRIM, SUBSTRING, POSITION) parse to these pg_catalog names.
    ALLOWED_FUNCTIONS = %w[count sum avg min max round abs floor ceil coalesce nullif greatest least lower upper length
      concat date_trunc date_part age to_char now pg_catalog.extract pg_catalog.btrim pg_catalog.substring pg_catalog.position].freeze

    def self.call(sql, allowed_relations:)
      tree = parse(sql)
      single_select!(tree)
      tree.walk! { |_parent, _key, node, _location| inspect_node!(node) }
      raise Unsafe, "Schema-qualified names are not allowed" if tree.tables_with_details.any? { _1[:schemaname].present? }

      relations = tree.tables.uniq
      (relations - allowed_relations).first&.then { raise Unsafe, "Relation not allowed: #{_1}" }
      (tree.functions.uniq - ALLOWED_FUNCTIONS).first&.then { raise Unsafe, "Function not allowed: #{_1}" }
      relations
    end

    def self.parse(sql)
      PgQuery.parse(sql)
    rescue PgQuery::ParseError
      raise Unsafe, "Generated SQL could not be parsed"
    end

    def self.single_select!(tree)
      statements = tree.tree.stmts
      raise Unsafe, "Only a single SELECT statement is allowed" unless statements.one? && statements.first.stmt.node == :select_stmt
    end

    def self.inspect_node!(node)
      case node
      when PgQuery::SelectStmt
        raise Unsafe, "Locking and SELECT INTO are not allowed" if node.locking_clause.any? || node.into_clause
      when PgQuery::TypeCast
        raise Unsafe, "Casts to reg* types are not allowed" if node.type_name.names.any? { _1.string.sval.start_with?("reg") }
      end
    end
    private_class_method :parse, :single_select!, :inspect_node!
  end
end
