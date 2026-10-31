let testCartMainLua = """
    function _init()
      frames = 0
    end

    function _update()
      frames = frames + 1
      if frames == 120 then
        frames = frames + speed
      end
    end
    """
