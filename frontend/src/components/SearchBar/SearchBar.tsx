import {
  useState,
  useCallback,
  useRef,
  useEffect,
  memo,
  forwardRef,
  useImperativeHandle,
} from 'react';
import { Search, X, Loader2 } from 'lucide-react';
import clsx from 'clsx';
import { useDebounce } from '../../hooks';
import './SearchBar.css';

export interface SearchBarRef {
  focus: () => void;
  clear: () => void;
}

export interface SearchBarProps {
  placeholder?: string;
  value?: string;
  onChange?: (value: string) => void;
  onSearch?: (value: string) => void;
  onSubmit?: (value: string) => void;
  debounceMs?: number;
  minLength?: number;
  showIcon?: boolean;
  showClear?: boolean;
  clearOnEscape?: boolean;
  autoFocus?: boolean;
  disabled?: boolean;
  loading?: boolean;
  size?: 'sm' | 'md' | 'lg';
  fullWidth?: boolean;
  className?: string;
}

export const SearchBar = memo(
  forwardRef<SearchBarRef, SearchBarProps>(function SearchBar(
    {
      placeholder = 'Search...',
      value: controlledValue,
      onChange,
      onSearch,
      onSubmit,
      debounceMs = 300,
      minLength = 0,
      showIcon = true,
      showClear = true,
      clearOnEscape = true,
      autoFocus = false,
      disabled = false,
      loading = false,
      size = 'md',
      fullWidth = false,
      className,
    },
    ref
  ) {
    const [internalValue, setInternalValue] = useState('');
    const inputRef = useRef<HTMLInputElement>(null);

    const value =
      controlledValue !== undefined ? controlledValue : internalValue;

    const { debouncedValue } = useDebounce(value, debounceMs);

    // Debounced search
    useEffect(() => {
      if (
        onSearch &&
        debouncedValue !== undefined &&
        debouncedValue.length >= minLength
      ) {
        onSearch(debouncedValue);
      }
    }, [debouncedValue, onSearch, minLength]);

    const handleChange = useCallback(
      (e: React.ChangeEvent<HTMLInputElement>) => {
        const newValue = e.target.value;

        if (controlledValue === undefined) {
          setInternalValue(newValue);
        }

        onChange?.(newValue);
      },
      [controlledValue, onChange]
    );

    const handleClear = useCallback(() => {
      if (controlledValue === undefined) {
        setInternalValue('');
      }

      onChange?.('');
      onSearch?.('');
      inputRef.current?.focus();
    }, [controlledValue, onChange, onSearch]);

    const handleKeyDown = useCallback(
      (e: React.KeyboardEvent<HTMLInputElement>) => {
        if (e.key === 'Escape' && clearOnEscape) {
          handleClear();
        }

        if (e.key === 'Enter') {
          onSubmit?.(value);
        }
      },
      [handleClear, clearOnEscape, onSubmit, value]
    );

    // Imperative API
    useImperativeHandle(ref, () => ({
      focus: () => inputRef.current?.focus(),
      clear: handleClear,
    }));

    const iconSize = size === 'sm' ? 14 : size === 'lg' ? 20 : 16;

    return (
      <div
        className={clsx(
          'search-bar',
          disabled && 'search-bar--disabled',
          size !== 'md' && `search-bar--${size}`,
          fullWidth && 'search-bar--full',
          className
        )}
        role="search"
      >
        {showIcon && !loading && (
          <span className="search-bar__icon">
            <Search size={iconSize} />
          </span>
        )}

        {loading && (
          <span className="search-bar__icon search-bar__spinner">
            <Loader2 size={iconSize} className="spin" />
          </span>
        )}

        <input
          ref={inputRef}
          type="text"
          className="search-bar__input"
          placeholder={placeholder}
          value={value}
          onChange={handleChange}
          onKeyDown={handleKeyDown}
          autoFocus={autoFocus}
          disabled={disabled}
          aria-label="Search"
          aria-busy={loading}
        />

        {showClear && value && !disabled && (
          <button
            type="button"
            className="search-bar__clear"
            onClick={handleClear}
            aria-label="Clear search"
          >
            <X size={14} />
          </button>
        )}
      </div>
    );
  })
);

export default SearchBar;
